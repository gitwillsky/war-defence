# asset_pipeline

离线素材管线，设计见 [docs/design/asset-pipeline.md](../../docs/design/asset-pipeline.md)。

```
make setup       # 一次性：创建 .venv 并装依赖
make mix-list    # 列出原始素材里所有 MIX
```

| 目录 | 作用 | 状态 |
|------|------|------|
| `mix/` | MIX 归档读取（明文 / Blowfish 加密头 / 旧格式）、文件名哈希 | 已完成 |
| `formats/` | SHP / VXL / HVA / PAL / CSF / INI 解码 | 待做 |
| `render/` | VXL 方向渲染 | 待做 |
| `pack/` | 图集与 manifest 写出 | 待做 |
