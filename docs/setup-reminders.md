# Setup Reminders

## 1) Initialize submodules first
Run:
- `git submodule update --init --recursive`

Many build/test issues come from missing submodule code.

## 2) Install JS deps
- `yarn install`

## 3) Common sanity checks
- `git submodule status`
- `node -v` / `yarn -v`
