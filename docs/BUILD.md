# 构建指南

本文档描述如何在本地和CI环境中构建xdelta3项目。

## 📋 目录

- [快速开始](#快速开始)
- [构建要求](#构建要求)
- [本地构建](#本地构建)
- [CI构建](#ci构建)
- [构建配置](#构建配置)
- [故障排除](#故障排除)

## 🚀 快速开始

### Windows

```powershell
# 克隆仓库
git clone https://github.com/your-repo/xdelta.git
cd xdelta

# 运行构建脚本
.\build.ps1

# 或指定参数
.\build.ps1 -BuildType Debug -Arch x86
```

### Linux/macOS

```bash
# 克隆仓库
git clone https://github.com/your-repo/xdelta.git
cd xdelta

# 运行构建脚本
./build.sh

# 或指定参数
./build.sh --build-type Debug --arch x64
```

## 📦 构建要求

### 通用要求

- **CMake** 3.15 或更高版本
- **Git** 2.0 或更高版本
- **vcpkg** (自动设置)

### Windows特定要求

- **Visual Studio 2019/2022** 或 **Build Tools for Visual Studio**
- **PowerShell** 5.1 或更高版本

### Linux特定要求

- **GCC** 7.0 或更高版本，或 **Clang** 6.0 或更高版本
- **Make** 或 **Ninja**

### 可选依赖

- **ccache** - 加速编译（强烈推荐）

## 🔧 本地构建

### 使用构建脚本（推荐）

项目提供了统一的构建脚本，确保本地和CI环境的一致性：

#### Windows

```powershell
# 基本构建
.\build.ps1

# 自定义构建
.\build.ps1 -BuildType Release -Arch x64 -Jobs 4

# 禁用ccache
.\build.ps1 -NoCcache

# 检查依赖
.\build.ps1 -CheckDeps

# 显示帮助
.\build.ps1 -Help
```

#### Linux/macOS

```bash
# 基本构建
./build.sh

# 自定义构建
./build.sh --build-type Release --arch x64 --jobs 4

# 禁用ccache
./build.sh --no-ccache

# 检查依赖
./build.sh --check-deps

# 显示帮助
./build.sh --help
```

### 手动构建

如果您需要更多控制，可以手动执行构建步骤：

#### 1. 设置vcpkg

```bash
# 克隆vcpkg
git clone https://github.com/Microsoft/vcpkg.git

# Windows
cd vcpkg
.\bootstrap-vcpkg.bat

# Linux/macOS
cd vcpkg
./bootstrap-vcpkg.sh
```

#### 2. 安装依赖

```bash
# Windows x64
vcpkg install liblzma:x64-windows

# Linux x64
vcpkg install liblzma:x64-linux
```

#### 3. 配置CMake

```bash
# Windows
cmake -B build -S . -A x64 \
  -DCMAKE_TOOLCHAIN_FILE=vcpkg/scripts/buildsystems/vcpkg.cmake \
  -DVCPKG_TARGET_TRIPLET=x64-windows \
  -DCMAKE_BUILD_TYPE=Release

# Linux
cmake -B build -S . \
  -DCMAKE_TOOLCHAIN_FILE=vcpkg/scripts/buildsystems/vcpkg.cmake \
  -DVCPKG_TARGET_TRIPLET=x64-linux \
  -DCMAKE_BUILD_TYPE=Release
```

#### 4. 构建

```bash
cmake --build build --config Release --parallel 4
```

## 🤖 CI构建

### GitHub Actions工作流

项目使用模块化的GitHub Actions工作流：

#### 主要工作流

1. **reusable-build-v2.yml** - 可复用的构建工作流
2. **pr-build-test.yml** - PR构建测试
3. **release.yml** - 发布构建

#### 使用可复用工作流

```yaml
jobs:
  build:
    uses: ./.github/workflows/reusable-build-v2.yml
    with:
      build_type: 'Release'
      platforms: '["windows", "linux"]'
      architectures: '["x64", "x86"]'
      enable_ccache: true
```

### 构建矩阵

CI支持以下构建配置：

| 平台 | 架构 | 构建类型 | 编译器 |
|------|------|----------|--------|
| Windows | x64, x86 | Debug, Release | MSVC |
| Linux | x64 | Debug, Release | GCC |

## ⚙️ 构建配置

### 配置文件

构建配置统一存储在 `.github/config/build-config.yml` 中：

```yaml
# vcpkg配置
vcpkg:
  commit: "a34c873a9717a888f58dc05268dea15592c2f0ff"
  max_concurrency: 2

# 构建配置
build:
  default_type: "Release"
  parallel_jobs: 2
  cmake_options:
    common:
      - "-DXDELTA_ENABLE_LZMA=ON"
      - "-DXDELTA_BUILD_TESTS=OFF"
```

### CMake选项

| 选项 | 默认值 | 描述 |
|------|--------|------|
| `XDELTA_ENABLE_LZMA` | ON | 启用LZMA压缩支持 |
| `XDELTA_BUILD_TESTS` | OFF | 构建测试 |
| `CMAKE_BUILD_TYPE` | Release | 构建类型 |

### 环境变量

| 变量 | 描述 |
|------|------|
| `VCPKG_KEEP_ENV_VARS` | 保留的环境变量 |
| `VCPKG_MAX_CONCURRENCY` | vcpkg最大并发数 |

## 🔧 故障排除

### 常见问题

#### 1. vcpkg安装失败

```bash
# 清理vcpkg缓存
vcpkg remove --outdated
vcpkg install liblzma:x64-windows --clean-after-build
```

#### 2. CMake配置失败

```bash
# 清理构建目录
rm -rf build
mkdir build

# 重新配置
cmake -B build -S . [your-options]
```

#### 3. 编译错误

```bash
# 检查编译器版本
gcc --version  # Linux
cl            # Windows

# 更新vcpkg
cd vcpkg
git pull
./bootstrap-vcpkg.sh  # 或 .bat
```

#### 4. 缓存问题

```bash
# 清理ccache
ccache -C

# 清理CMake缓存
rm -rf build/CMakeCache.txt build/CMakeFiles
```

### 调试构建

#### 启用详细输出

```bash
# CMake详细输出
cmake -B build -S . -DCMAKE_VERBOSE_MAKEFILE=ON

# 构建详细输出
cmake --build build --verbose
```

#### 检查依赖

```bash
# Windows
.\build.ps1 -CheckDeps

# Linux
./build.sh --check-deps
```

### 获取帮助

如果遇到问题，请：

1. 检查[Issues](https://github.com/your-repo/xdelta/issues)
2. 查看[构建日志](https://github.com/your-repo/xdelta/actions)
3. 提交新的Issue，包含：
   - 操作系统和版本
   - 构建命令
   - 完整的错误日志

## 📚 相关文档

- [开发指南](DEVELOPMENT.md)
- [发布流程](RELEASE.md)
- [CI配置](CI.md)
