{
  flake.nixosModules.llama =
    { pkgs, ... }:
    let
      # router 模式的 preset 文件；每加一个模型就加一个 section（段名就是 API 里的 model id）。
      # 键名直接用 llama-server 的长参数名（去掉 --），例如 ctx-size / n-gpu-layers。
      modelsPreset = pkgs.writeText "llama-models.ini" ''
        version = 1

        ; [*] 对所有模型生效的默认采样参数，单个模型段内可覆盖
        [*]
        temp = 0.7
        repeat-penalty = 1.05
        top-k = 80

        [Qwen2.5-7B-Instruct]
        hf = Qwen/Qwen2.5-7B-Instruct-GGUF:Q4_K_M
        ctx-size = 8192

        ; 第二个模型示例（换成自己的仓库和量化）：
        ; [Other-Model-7B]
        ; hf = <user>/<repo-GGUF>:Q4_K_M
        ; ctx-size = 8192
      '';
    in
    {
      services.llama-cpp = {
        enable = true;
        package = pkgs.llama-cpp-vulkan;

        # 不设 settings.model/hf-repo → router 模式：按请求里的 model 字段懒加载
        settings = {
          models-preset = modelsPreset;
          models-max = 1; # 同时只驻留 1 个模型，切换时按 LRU 卸载
          sleep-idle-seconds = 300; # 空闲 5 分钟连权重和 KV cache 一起释放
        };
      };

      # DynamicUser 没有 HOME，Mesa/RADV 会把 shader 缓存目录算成 `//.cache`
      # 并因根目录只读而禁用磁盘 shader 缓存，导致每次启动重新编译 Vulkan pipeline。
      systemd.services.llama-cpp.environment.HOME = "/var/lib/llama-cpp";
    };
}
