# 本仓库自身的 CI 定时任务，由 home-server 上的 nixbot 执行（不是 NixOS 模块）。
#
# nixbot 在每次默认分支（main）构建成功后，从 flake 的 `herculesCI.onSchedule`
# 里发现定时任务并持久化，之后按 `when`（**UTC**）触发。每次运行都 checkout
# 默认分支的最新 commit，所以这里的改动要先合进 main 才生效；PR 里改它不会
# 给自己加任务。
#
# 两个任务：
#   flake-update  每周更新 flake.lock 里所有直接 input，开 PR 到 main，等检查通过后自动 squash 合并
#   daily-merge   每天晚上把 main 合回 daily，再开好 daily → main 的 PR 并 arm auto-merge
#
# GitHub 侧前提：
#   · App 权限 Contents: Write（effect 要 push）、Checks: Write（上报 check run）
#   · 仓库设置里允许 Allow auto-merge
#   · main 的 branch protection 把 `nixbot/nix-eval`、`nixbot/nix-build` 设为 required checks。
#     不要加 `nixbot/effects`：本次构建没有任何 effect 条目时它根本不会被上报
#     （effect_checks.enqueue_checks 在 names 为空时直接 return），而没上报过的
#     required check 会让 PR 永远停在 "Waiting for status to be reported"。
{ self, ... }:
let
  pkgs = self.inputs.nixpkgs.legacyPackages.x86_64-linux;
  effects = self.inputs.nixbot.lib.effects { inherit pkgs; };
  inherit (effects) flakeUpdate mkEffect;
in
{
  flake.herculesCI =
    { primaryRepo, ... }:
    let
      ownerRepo = "${primaryRepo.owner}/${primaryRepo.name}";
    in
    {
      # ── 任务 2：每周更新所有 input ────────────────────────────────────
      onSchedule.flake-update = {
        when = {
          dayOfWeek = [ "Sun" ];
          hour = [ 8 ];
        };
        outputs.effects.update = flakeUpdate {
          inherit (primaryRepo) forgeType;
          updateBranch = "flake-update";
          commitSummary = "flake.lock: update";
          # 等 required checks 通过后由 GitHub 自己 squash 合并；
          # 只在 github / gitea 上有效。
          autoMergeMethod = "squash";
          excludeInputs = [ "old-nixpkgs" ];
          # perInput = true;
        };
      };

      # ── 任务 1：每天晚上 daily → main ─────────────────────────────────
      onSchedule.daily-merge = {
        when = {
          hour = [ 20 ];
        };
        outputs.effects.pr = mkEffect {
          name = "daily-to-main";
          # 合并 + push 需要可写的克隆：nixbot 把仓库 clone 到 /build/checkout
          # （也就是 cwd，并导出为 $NIXBOT_EFFECT_CHECKOUT），origin 指向带
          # GitHub App token 的 URL，所以 git push 不用额外 secret。
          # 注意它是 detached HEAD、没有本地分支、没有 committer 身份。
          checkout = true;
          inputs = [
            pkgs.gh
            pkgs.git
          ];
          # { type = "GitToken"; } = 本次运行的 forge token，在脚本里以
          # {"data":{"token":...}} 的形式出现，用 readSecretString 取。
          secretsMap.token = {
            type = "GitToken";
          };
          effectScript = ''
            set -euo pipefail
            export GH_TOKEN="$(readSecretString token .token)"
            cd "$NIXBOT_EFFECT_CHECKOUT"

            # effect 克隆没有 committer 身份，merge 提交需要自己配
            git config user.name nixbot
            git config user.email nixbot@localhost

            repo=${ownerRepo}
            base=main
            dev=daily
            git fetch --quiet --prune origin

            # ── 1) 先把 main 合回 daily ──────────────────────────────
            # 只落在 main 上的提交（每周 flake-update 的 flake.lock）如果不
            # 带回 daily，每晚的 daily → main 就会用 daily 的旧 lock 覆盖它
            # 或者直接冲突。
            git checkout --quiet -B "$dev" "origin/$dev"
            if ! git merge --no-ff --no-edit \
              -m "chore: merge $base into $dev" "origin/$base"; then
              echo "❌ $base → $dev 合并冲突，需要手动解决：" >&2
              git --no-pager diff --name-only --diff-filter=U >&2
              exit 1
            fi
            if [ "$(git rev-parse HEAD)" != "$(git rev-parse "origin/$dev")" ]; then
              git push --quiet origin "$dev"
              echo "已把 $base 合回 $dev"
            fi

            # ── 2) daily 没有 main 缺少的提交就收工，不建空 PR ───────
            if [ "$(git rev-list --count "origin/$base..$dev")" -eq 0 ]; then
              echo "$dev 没有可合并到 $base 的提交，跳过"
              exit 0
            fi

            # ── 3) 同一时间只留一个 PR ───────────────────────────────
            if [ "$(gh pr list --repo "$repo" --base "$base" --head "$dev" \
              --state open --json number --jq length)" -eq 0 ]; then
              gh pr create --repo "$repo" \
                --base "$base" --head "$dev" \
                --title "chore: $dev → $base ($(date -u +%F))" \
                --body "由 nixbot 定时任务创建，检查通过后自动合并。"
            fi

            # ── 4) 只 arm auto-merge，合并交给 GitHub 等 required checks ──
            # 放在 push 之后：head 变化时 GitHub 可能把 auto-merge 关掉。
            if [ "$(gh pr view --repo "$repo" "$dev" \
              --json autoMergeRequest --jq '.autoMergeRequest != null')" != "true" ]; then
              gh pr merge --repo "$repo" "$dev" --auto --squash
            fi
          '';
        };
      };
    };
}
