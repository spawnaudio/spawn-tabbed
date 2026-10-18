### windows are better 
# tabbed

https://github.com/user-attachments/assets/8b628294-754c-44bd-9088-425cc25b8098

```sh
brew trust --cask zimengxiong/tools/tabbed
brew tap ZimengXiong/tools
brew install --cask tabbed
xattr -dr com.apple.quarantine /Applications/Tabbed.app
```
on first launch, grant **System Settings -> Privacy & Security -> Accessibility**

hold ⌘ while dragging windows to create tab groups

use kb shortcuts alt+1...n to switch between tabs, and alt+tab to cycle between tabs. configure other bindings in ~/.config/tabbed.toml. a config is created for you on first launch

drag a tab sideways to reorder it; right-click a tab to remove it from the group or close the window

tag any window with ctrl+alt+shift+letter, then jump back to it from anywhere with ctrl+alt+letter (`[marks]` in the config)

new windows from apps listed in `[rules] auto_group` (comma-separated bundle ids) tab together automatically

groups are saved and restored when Tabbed restarts, as long as the apps stay open. turn on "Launch at Login" in the menu bar

in ~/.config/tabbed.toml you can also change the drag modifier (`[drag] modifier = "cmd"`) and the strip theme (`[appearance] theme = "system" | "dark" | "light"`)
