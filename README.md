# Xdelta vcpkg Registry

This is the official vcpkg registry for the xdelta library.

## Usage

To use this registry with vcpkg, add it to your vcpkg configuration:

```json
{
  "registries": [
    {
      "kind": "git",
      "repository": "https://github.com/loonghao/xdelta",
      "reference": "vcpkg-registry",
      "packages": ["xdelta"]
    }
  ]
}
```

Then you can install xdelta using:

```bash
vcpkg install xdelta
```

## Package Information

- **Package Name**: xdelta
- **Version**: 3.1.0
- **Description**: A binary delta compression library and command-line tool
- **Homepage**: https://github.com/loonghao/xdelta

## Files Structure

- `ports/xdelta/` - Contains the port definition files
- `versions/` - Contains version database files
- `README.md` - This file

## Automatic Updates

This registry is automatically updated when new releases are created in the main repository.
