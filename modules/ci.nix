# 本仓库自身的 CI：main 分支部署 + 定时任务，由 home-server 上的 nixbot 执行
# （不是 NixOS 模块）。
#
# nixbot 在每次默认分支（main）构建成功后，从 flake 的 `herculesCI` 里发现
# `onPush.default.outputs.effects` 并按 `after` / `lock` 执行；`onSchedule` 里的
# 定时任务则被持久化，之后按 `when`（**UTC**）触发。每次运行都 checkout 默认分支
# 的最新 commit，所以这里的改动要先合进 main 才生效；PR 里改它不会给自己加任务。
#
# PR 上 effect 不会真的跑（`effects_on_pull_requests` 默认关），但 nixbot 会把它们的
# 依赖当作 "Effect checks" 构建一遍——所以部署 effect 意味着 PR 也会构建各机器的
# toplevel（正好等价于 `clan machines build`）。
#
# 内容：
#   onPush.default  deploy-<machine>  每次 main push 后把机器切到本 commit 的配置
#                                   （NixOS 用 runNixOS，mac-mini 用 runNixDarwin）
#   onSchedule      flake-update      每周更新 flake.lock 里所有直接 input，开 PR 到 main
#   onSchedule      daily-merge       每天晚上把 main 合回 daily，再开好 daily → main 的 PR
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
  inherit (pkgs) lib;
  effects = self.inputs.nixbot.lib.effects { inherit pkgs; };
  inherit (effects)
    flakeUpdate
    mkEffect
    runNixDarwin
    runNixOS
    ;

  # 目标地址覆盖：home-server 就是这个 effect 的宿主，走公网域名（NAT 回环）
  # 不如直接打本机回环可靠。
  destinationOverride = {
    home-server = "root@127.0.0.1";
  };

  # 自动部署的机器清单：从 clan inventory 推导，不单独维护。条件：
  #   · machineClass 匹配（nixos → runNixOS，darwin → runNixDarwin）
  #   · inventory 里有 deploy.targetHost
  #   · 没有设 `clan.core.deployment.requireExplicitUpdate = true`
  #     那个选项的语义就是「不总是在线 / 不在常规更新周期」，正好等于要从自动
  #     部署里排除的机器（tencent、ali、rpi4、nixos-desktop、work-macbook 都设了它）。
  # 想让某台机器加入/退出自动部署就改那个选项，不用动这里。
  configSetFor =
    class: if class == "darwin" then self.darwinConfigurations else self.nixosConfigurations;

  deployableFor =
    class:
    let
      configurations = configSetFor class;
    in
    lib.filterAttrs (
      name: machine:
      machine.machineClass == class
      && (machine.deploy.targetHost or null) != null
      && !configurations.${name}.config.clan.core.deployment.requireExplicitUpdate
    ) self.clan.inventory.machines;

  # 一次部署 = runNixOS / runNixDarwin effect：构建好的 toplevel 用
  # nix-copy-closure 推到目标机，再在那边 `nix-env -p <profile> --set` + 切换配置
  # （NixOS 是 `switch-to-configuration switch`，darwin 是 `darwin-rebuild activate`）。
  # SSH 私钥来自 nixbot 的 effects secrets JSON（见 modules/services/nixbot.nix），
  # 公钥已经写进各机器 root 的 authorized_keys
  # （modules/common/nixbot-deploy-target.nix）。
  #
  # darwin 的 toplevel 是 home-server 通过 nix.buildMachines 里的 mac-mini
  # remote builder 编出来的（aarch64-darwin 原生构建），不需要 qemu。
  mkDeploys =
    class: deploy:
    let
      configurations = configSetFor class;
    in
    lib.mapAttrs' (
      name: machine:
      lib.nameValuePair "deploy-${name}" (deploy {
        configuration = configurations.${name};
        ssh = {
          destination = destinationOverride.${name} or machine.deploy.targetHost;
          # 沙箱里每次都是全新的 $HOME，没有 known_hosts；首次连接接受并记住目标
          # 主机公钥。
          sshOptions = "-o StrictHostKeyChecking=accept-new";
        };
        # 每台机器一把锁：两次 push 的部署不会在目标机上交错执行切换。
        lock = "deploy-${name}";
        # 与 JSON 里 data.privateKey 对应的 secretsMap 名字。
        secretsMap.ssh = "deploy-ssh";
        # runNixDarwin 自己会写 effectScript，key 只能在 userSetupScript 里准备。
        userSetupScript = "writeSSHKey ssh";
        # toplevel 没变就不重跑：否则每次 push 都会对每台机器跑一遍切换。
        # 只看上一次**成功**的运行，失败的会在下次 push 重试。
        when.changed.toplevel = configurations.${name}.config.system.build.toplevel.outPath;
      })
    ) (deployableFor class);
in
{
  flake.herculesCI =
    { primaryRepo, ... }:
    let
      ownerRepo = "${primaryRepo.owner}/${primaryRepo.name}";
    in
    {
      # ── 部署：默认分支 push 成功后把每台机器切到本次 commit ──────────────
      #
      # 注意 home-server 是 nixbot 自己所在的机器：switch 如果改动到 nixbot.service
      # （或它的依赖）会把跑 effect 的进程一起重启，这次 effect 会显示失败但配置其实
      # 已经生效；下一次 push 会重跑一遍（switch 无事可做）并记成成功。
      onPush.default.outputs.effects = mkDeploys "nixos" runNixOS // mkDeploys "darwin" runNixDarwin;
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

            # nixbot 的中心镜像本身是 blobless partial clone
            # （clone --bare --filter=blob:none），每次 effect 的检出却是从这个
            # 镜像 **本地路径** clone 出来的，而 git 不会把
            # remote.origin.promisor / partialclonefilter 带到新克隆里：结果这个
            # 检出看着普通，对象库里却只有镜像 materialize 过的那部分 blob。
            # 于是在里面 checkout 一个没被检出过的提交（比如 origin/daily 相对
            # 本次运行的 main 改动过的 modules/checks.nix）时，git 只会打两条
            # 「unable to read sha1 file / invalid object」然后**返回 0**，把这
            # 些文件从索引和工作区里删掉；接着 git merge 内部要跑
            # `git stash create`，就会以「Cannot save the current index state」
            # 「fatal: stash failed」失败，看上去像是冲突，其实一个冲突文件都没有。
            # 这里把检出标记成 partial clone，git 缺 blob 时就会去 origin
            # （nixbot 已把它换成带 token 的 forge URL）按需补拉。
            git config remote.origin.promisor true
            git config remote.origin.partialclonefilter blob:none

            # ── 1) 先把 main 合回 daily ──────────────────────────────
            # 只落在 main 上的提交（每周 flake-update 的 flake.lock）如果不
            # 带回 daily，每晚的 daily → main 就会用 daily 的旧 lock 覆盖它
            # 或者直接冲突。
            # 用默认 merge（允许 fast-forward）：daily 只是落后于 main 时直接
            # 快进，不会为「没有内容变化」留一个合并提交。
            git checkout --quiet -B "$dev" "origin/$dev"
            # 上面这条在缺 blob 时只打错误、仍返回 0（见上），工作区因此不干净时
            # 直接停下，别把问题拖成后面那句「合并冲突」。
            if [ -n "$(git status --porcelain)" ]; then
              echo "❌ 检出 $dev 后工作区不干净，本地对象库可能不全：" >&2
              git --no-pager status --short >&2
              exit 1
            fi
            if ! git merge --no-edit \
              -m "chore: merge $base into $dev" "origin/$base"; then
              if [ -n "$(git --no-pager diff --name-only --diff-filter=U)" ]; then
                echo "❌ $base → $dev 合并冲突，需要手动解决：" >&2
                git --no-pager diff --name-only --diff-filter=U >&2
              else
                echo "❌ $base → $dev 合并失败，但没有冲突文件" >&2
                echo "   （本地对象库不全或工作区不干净，不是内容冲突）" >&2
                git --no-pager status --short >&2
              fi
              exit 1
            fi
            if [ "$(git rev-parse HEAD)" != "$(git rev-parse "origin/$dev")" ]; then
              git push --quiet origin "$dev"
              echo "已把 $base 合回 $dev"
            fi

            # ── 2) 和 main 内容一致就不建 PR ─────────────────────────
            # 不能数提交：主线上的合并提交本身就让 daily 比 main「多」一个
            # commit，但两边 tree 完全一样，这种 PR 在 GitHub 上是空 diff。
            if git diff --quiet "origin/$base" "$dev"; then
              echo "$dev 与 $base 内容一致，没有可合并的改动，跳过"
              # 之前跑出来的空 PR 顺手关掉，别让它挂着 auto-merge
              if [ "$(gh pr list --repo "$repo" --base "$base" --head "$dev" \
                --state open --json number --jq length)" -gt 0 ]; then
                echo "关闭没有 diff 的旧 PR"
                gh pr close "$dev" --repo "$repo" \
                  --comment "$dev 与 $base 内容已一致，自动关闭。"
              fi
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
            # 用 --merge：main 会以合并提交包含 daily 的那些提交，第二天第 1 步
            # 就退化成纯快进（Already up to date），既不会产生空 PR，也不会有
            # 「squash 后的调和合并」。但这要求仓库设置里 Allow merge commits。
            if [ "$(gh pr view --repo "$repo" "$dev" \
              --json autoMergeRequest --jq '.autoMergeRequest != null')" != "true" ]; then
              gh pr merge --repo "$repo" "$dev" --auto --merge
            fi
          '';
        };
      };
    };
}
