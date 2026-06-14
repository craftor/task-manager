cask "task-manager" do
  version "0.12.3"
  sha256 "13c7514d0de0495582903f523202557cfb36e8af26c5c9c17139aae29ca1fa41"

  url "https://github.com/craftor/task-manager/releases/download/v#{version}/TaskManager_v#{version}_macos.dmg"
  name "Task Manager"
  desc "Personal task and time management application with Appwrite sync"
  homepage "https://github.com/craftor/task-manager"

  # The Flutter macOS Runner names the bundle `task_manager.app` regardless
  # of the human-readable app name (CFBundleName = "TaskManager"). The
  # binary inside also keeps that name. Keep the cask stanza in sync.
  app "task_manager.app"

  # Per-user files this app writes. Remove on `brew uninstall --zap task-manager`.
  # Confirmed against the macOS app's own storage:
  #   - ~/Library/Application Support/task_manager (Drift DB)
  #   - shared_preferences / secure_storage plists
  zap trash: [
    "~/Library/Application Support/task_manager",
    "~/Library/Preferences/cn.logicpi.TaskManager.plist",
    "~/Library/Saved Application State/cn.logicpi.TaskManager.savedState",
  ]

  caveats <<~EOS
    Task Manager uses a self-hosted Appwrite backend at http://o.21up.cn:6080.
    On first launch it will ask you to sign in or create an account there.
  EOS
end