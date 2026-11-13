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

        ; paperless 的 AI 建议（modules/services/paperless.nix）专用：同一份
        ; Qwen3.5-9B 权重，但要与对话场景不同的参数：
        ;   - temp 0：分类要确定性
        ;   - ctx 8192：paperless 的 PAPERLESS_AI_LLM_CONTEXT_SIZE 默认就是 8192
        ;   - 关 thinking：分类不需要思考，而且 thinking 模板下 llama.cpp 不保证
        ;     强制执行 tool_choice=required（upstream #27217），而 paperless 的
        ;     openai-like 路径正是 chat_with_tools(tool_required=True)，
        ;     拿不到 tool_calls 会直接报错。两重关闭：
        ;     chat-template-kwargs 让模板不渲染思考段，reasoning-budget 0 兜底。
        [paperless-classify]
        hf = unsloth/Qwen3.5-9B-GGUF:UD-Q4_K_XL
        ctx-size = 8192
        temp = 0
        chat-template-kwargs = {"enable_thinking":false}
        reasoning-budget = 0

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
        ; 让 llama-server 把 <|LOC_i|> / <|LOC_SEP|> 这类特殊 token 原样写进
        ; choices[].content（默认 --special=false 会把它们 detokenize 成空字符串）。
        ; 只在本段开，不影响上面两个 Qwen。
        ; 开了以后客户端可以直接用正则 <\|LOC_(\d+)\|> 解坐标，
        ; 不必再依赖 logprobs（响应体会小一个数量级）。
        special = true
      '';
    in
    {
      services.llama-cpp = {
        enable = true;
        package = pkgs.llama-cpp-vulkan;

        # 不设 settings.model/hf-repo → router 模式：按请求里的 model 字段懒加载
        settings = {
          port = 3119; # 原来是默认的 8080
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
