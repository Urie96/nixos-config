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
        ; preset 和 LLAMA_CACHE 里已下载的同一个模型文件只显示一条（否则 /models 会重复）
        dedup-cache-models = 1

        ; Qwen3.5-9B：多模态（mmproj 随 hf 自动下载），默认 thinking 模式，
        ; 采样参数取官方 thinking 推荐值。权重 5.56 GiB + mmproj 0.86 GiB，KV 另算。
        [Qwen3.5-9B]
        hf = unsloth/Qwen3.5-9B-GGUF:UD-Q4_K_XL
        ctx-size = 16384
        temp = 1.0
        top-p = 0.95
        top-k = 20
        repeat-penalty = 1.0
        presence-penalty = 1.5

        ; PaddleOCR-VL-1.6：0.9B 文档解析 VLM（NaViT 视觉塔 + ERNIE-4.5-0.3B），
        ; 权重 892 MiB + mmproj 841 MiB（官方仓库只有 F16），mmproj 随 hf 自动下载。
        ; 必须 temp 0，否则输出发散。它不是通用对话模型，prompt 只用固定指令：
        ; OCR: / Table Recognition: / Formula Recognition: / Chart Recognition: /
        ; Seal Recognition: / Spotting:（Spotting 需把 mmproj 的 clip.vision.image_max_pixels
        ; 从 1003520 调到 1605632，model 自带的默认值够 OCR/表格用）。
        ; 注意：这里只做元素级识别；整页版面解析要用 PaddleOCR 的 pipeline，
        ; 把 vl_rec_backend 指到 llama-cpp-server + 本服务的 /v1。
        [PaddleOCR-VL-1.6]
        hf = PaddlePaddle/PaddleOCR-VL-1.6-GGUF
        ctx-size = 8192
        temp = 0
      '';
    in
    {
      services.llama-cpp = {
        enable = true;
        package = pkgs.llama-cpp-vulkan;

        # 不设 settings.model/hf-repo → router 模式：按请求里的 model 字段懒加载
        settings = {
          models-preset = modelsPreset;
          models-max = 2; # 同时只驻留 2 个模型，切换时按 LRU 卸载
          sleep-idle-seconds = 300; # 空闲 5 分钟连权重和 KV cache 一起释放
        };
      };

      # DynamicUser 没有 HOME，Mesa/RADV 会把 shader 缓存目录算成 `//.cache`
      # 并因根目录只读而禁用磁盘 shader 缓存，导致每次启动重新编译 Vulkan pipeline。
      systemd.services.llama-cpp.environment.HOME = "/var/lib/llama-cpp";
    };
}
