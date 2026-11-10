# Trusted Caches

Configures nix to trust and use external binary caches. A generic
replacement for hardcoded cache modules — add any cache through the
inventory settings.

## Roles

### default

| Setting  | Type          | Description                    |
| -------- | ------------- | ------------------------------ |
| `caches` | list of cache | Binary caches to trust and use |

Each cache entry:

| Field       | Type  | Default | Description                        |
| ----------- | ----- | ------- | ---------------------------------- |
| `url`       | `str` | —       | Cache URL                          |
| `publicKey` | `str` | —       | Public signing key                 |
| `priority`  | `int` | `42`    | Substituter priority (lower=first) |

## Example

```nix
trusted-caches = {
  module = { name = "@adeci/trusted-caches"; input = "self"; };
  roles.default = {
    tags = [ "my-network" ];
    settings.caches = [
      {
        url = "https://cache.numtide.com";
        publicKey = "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=";
        priority = 42;
      }
    ];
  };
};
```
