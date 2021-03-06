name: Convert Tabs to spaces on SQL files

on:
  push:
    branches-ignore:
    - "release/*"
    - "hotfix/*"
    - "feature/*"

jobs:
  tabs-to-spaces:

    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v1
    - name: Configure Git
      run: |
        git config --local user.email "credfeto@users.noreply.github.com"
        git config --local user.name "Mark Ridgwell"
    - name: Install MoreUtils
      run: |
        sudo apt-get install moreutils
    - name: Convert tabs to spaces
      run: |
        find ./ -iname '*.sql' -type f -exec bash -c 'expand -t 4 "$0" | sponge "$0"' {} \;
    - name: Commit files
      run: |
        git commit --all -m"Converted Tabs to spaces" || true
        echo Converted
    - name: Push changes
      uses: ad-m/github-push-action@master
      with:
        github_token: ${{ secrets.GITHUB_TOKEN }}
