# Windows 侧载安装指南

本指南帮助你在 **没有 Mac** 的前提下，用 GitHub Actions 免费编译无签名 IPA，通过 **Sideloadly** 安装到 iPhone，并用 Windows 上的 Flask 服务接收 Apple 健康数据。

---

## 一、项目结构说明

| 组件 | 路径 | 作用 |
|------|------|------|
| iOS App | `AppleHealthExporter/` | SwiftUI + HealthKit，一键同步到电脑 |
| Xcode 工程 | `AppleHealthExporter.xcodeproj` | 供 GitHub macOS 虚拟机编译 |
| CI 工作流 | `.github/workflows/build-unsigned.yml` | 无证书编译并打包 `.ipa` |
| 接收服务 | `server.py` | Windows 本机 `5000` 端口，写入 `health_data.csv` |

---

## 二、在 Windows 上启动数据接收服务

### 1. 安装 Python 3.10+

从 [python.org](https://www.python.org/downloads/) 安装，勾选 **Add Python to PATH**。

### 2. 安装依赖并启动

在项目根目录打开 PowerShell：

```powershell
cd d:\cursor-project\AppleHealth_Exporter
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python server.py
```

看到类似输出即表示成功：

```text
Listening on http://0.0.0.0:5000
POST endpoint: http://<your-lan-ip>:5000/api/health
```

### 3. 查看本机局域网 IP

```powershell
ipconfig
```

记下 **无线局域网适配器 WLAN** 下的 `IPv4 地址`，例如 `192.168.1.100`。

### 4. 放行防火墙

首次运行时若 Windows 防火墙弹窗，请允许 **专用网络** 访问 Python。

也可手动添加入站规则：TCP **5000** 端口，专用网络。

### 5. 验证服务

浏览器访问：`http://192.168.1.100:5000/health`（换成你的 IP），应返回 JSON `{"ok": true, ...}`。

---

## 三、推送代码到 GitHub 并获取 IPA

### 1. 创建 GitHub 仓库

在 GitHub 新建空仓库，例如 `AppleHealth-Exporter`。

### 2. 初始化并推送（本地 PowerShell）

```powershell
cd d:\cursor-project\AppleHealth_Exporter
git init
git add .
git commit -m "Initial Apple Health Exporter stack"
git branch -M main
git remote add origin https://github.com/<你的用户名>/AppleHealth-Exporter.git
git push -u origin main
```

### 3. 触发编译

推送后工作流会自动运行；也可在 GitHub 仓库页：

**Actions** → **Build Unsigned IPA** → **Run workflow**

### 4. 下载 IPA 产物

1. 进入该次 Workflow 运行详情页  
2. 滚动到 **Artifacts**  
3. 下载 **AppleHealthExporter-unsigned-ipa**  
4. 解压得到 `AppleHealthExporter.ipa`

> 编译在 `macos-latest` 上执行，使用参数  
> `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""`  
> 生成 **无签名** 安装包，需在 Windows 上用 Sideloadly 重新签名安装。

---

## 四、用 Sideloadly 侧载到 iPhone

### 1. 准备工具

- 安装 [Sideloadly](https://sideloadly.io/)（Windows 版）
- 安装 [iTunes 或 Apple 设备支持驱动](https://www.apple.com/itunes/download/)（用于识别设备）
- 数据线连接 iPhone 与电脑，在手机上点 **信任此电脑**

### 2. 侧载步骤

1. 打开 Sideloadly  
2. **IPA 文件**：选择下载的 `AppleHealthExporter.ipa`  
3. **Apple ID**：填写你的 Apple ID（仅用于本机签名，不会上传源码）  
4. 设备列表中选择你的 iPhone  
5. 点击 **Start**，按提示输入 Apple ID 密码或双重认证  
6. 等待安装完成

### 3. 信任开发者（首次必做）

**设置** → **通用** → **VPN 与设备管理** → 选择你的 Apple ID → **信任**

### 4. 免费 Apple ID 限制

- 应用约 **7 天** 后需重新侧载  
- 免费账号对 HealthKit 等能力可能有限制；若无法读取健康数据，可考虑付费开发者账号或使用 AltStore 等方案

---

## 五、在 iPhone 上同步健康数据

1. 确保 iPhone 与 Windows 电脑连接 **同一 Wi‑Fi**  
2. 打开 **Health Exporter** App  
3. 在 IP 输入框填写电脑 IP，例如 `192.168.1.100`（无需加 `http` 或端口，App 会自动使用 `:5000`）  
4. 点击 **一键同步全部健康数据**  
5. 首次使用会弹出 HealthKit 权限，建议在 **设置 → 健康 → 数据访问与设备 → Health Exporter** 中开启 **全部读取权限**（数据越多越完整）  

### 导出范围（约 90+ 类指标）

| 类别 | 示例 |
|------|------|
| 活动与运动 | 步数、距离、爬楼、锻炼/站立时长、健身记录 |
| 心脏与呼吸 | 心率、静息心率、HRV、血氧、呼吸频率、VO₂ Max |
| 身体与体征 | 体重、身高、BMI、体脂、血压、血糖、体温 |
| 睡眠与正念 | 睡眠阶段、正念时长 |
| 营养 | 热量、蛋白质、碳水、饮水、咖啡因等 |
| 步行能力 | 步速、步幅、不对称、双足支撑等 |
| 症状与生理 | 头痛、疲劳、月经、孕检等（健康 App 有记录才会导出） |
| 用户特征 | 出生日期、性别、血型等（仅历史全量同步一次） |

> **说明**：只能导出 HealthKit 允许第三方读取的数据；临床病历、部分苹果私有数据无法导出。设备/手表没有的数据会自动跳过。

同步按 **指标类型分批** 上传（每批最多 2500 条），降低内存占用：

- `all_history`：从最早记录至今  
- `today`：当日 0 点至今  

CSV 新增 `metric`、`metadata` 列；若你已有旧版 `health_data.csv`，建议先备份后删除，让服务重新生成表头。

### 在 Windows 上查看结果

数据保存在项目根目录：

```text
health_data.csv
```

可用 Excel、WPS 或 Python/pandas 打开分析。

---

## 六、常见问题

### Q1：App 显示「上传失败」

- 确认 `server.py` 正在运行  
- 确认 IP 正确且手机与电脑同一局域网  
- 在 iPhone Safari 访问 `http://<电脑IP>:5000/health` 测试连通性  
- 检查 Windows 防火墙是否放行 5000 端口  

### Q2：GitHub Actions 编译失败

- 在 Actions 日志中查看 `xcodebuild` 报错  
- 确认仓库包含完整的 `AppleHealthExporter.xcodeproj` 与 `xcscheme`  
- 若因 HealthKit entitlement 报错，可在 Issues 中反馈日志（部分环境下无签名构建需调整 entitlement）  

### Q3：HealthKit 无数据或权限灰色

- 确认数据在系统 **健康** App 中本身存在  
- 设置 → 健康 → 数据访问与设备 → **Health Exporter** → 打开全部读取权限  
- 睡眠、心率需 Apple Watch 或支持设备才有历史记录  

### Q4：历史数据量很大，同步较慢

- 首次同步会读取全部样本，耗时取决于数据量  
- 可保持屏幕常亮、勿切换 App，直至进度条走完  

---

## 七、安全提示

- 健康数据仅在 **你的局域网** 内传输，不会经过第三方服务器  
- GitHub Actions 仅编译代码，不上传你的健康数据  
- `health_data.csv` 含敏感信息，请勿上传到公开仓库（已在 `.gitignore` 中忽略）  
- 侧载使用的 Apple ID 密码由 Sideloadly 本地处理，请从官网下载工具，避免来路不明版本  

---

## 八、快速命令备忘

```powershell
# 启动接收服务
cd d:\cursor-project\AppleHealth_Exporter
.\.venv\Scripts\Activate.ps1
python server.py

# 查看 CSV 行数
(Get-Content health_data.csv | Measure-Object -Line).Lines
```

```text
# iPhone App 填写
192.168.x.x

# 手动测试 POST（可选，PowerShell）
$body = '{"synced_at":"2026-01-01T00:00:00Z","scope":"test","records":[{"type":"steps","value":"100","unit":"count","start_date":"2026-01-01T00:00:00Z","end_date":"2026-01-01T01:00:00Z","source":"test"}]}'
Invoke-RestMethod -Uri "http://127.0.0.1:5000/api/health" -Method Post -Body $body -ContentType "application/json"
```

---

完成以上步骤后，你即可在 Windows 环境下完成：**云端编译 IPA → 侧载安装 → 一键导出 Apple 健康数据到本地 CSV** 的完整闭环。
