# Spec: cli-path-install

Symlink alm, rws, sds to `~/.local/bin/`:
```sh
ln -sf <furrow-root>/bin/alm ~/.local/bin/alm
ln -sf <furrow-root>/bin/rws ~/.local/bin/rws
ln -sf <furrow-root>/bin/sds ~/.local/bin/sds
```

Verify: `which alm && which rws && which sds` all resolve.

## AC
- alm, rws, sds symlinked to ~/.local/bin and runnable without full path
- install.sh symlink logic verified end-to-end
