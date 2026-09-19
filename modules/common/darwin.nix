{ withSystem, ... }:
{
  flake.darwinModules.common =
    {
      self,
      config,
      pkgs,
      lib,
      ...
    }:
    let
      partsArgs = withSystem config.nixpkgs.hostPlatform.system (args: args);
    in
    {
      imports = [
        self.inputs.nix-homebrew.darwinModules.nix-homebrew
        self.inputs.srvos.darwinModules.mixins-trusted-nix-caches
        self.inputs.srvos.darwinModules.common
        self.inputs.srvos.darwinModules.mixins-terminfo
        self.inputs.srvos.darwinModules.mixins-nix-experimental
      ];

      _module.args = { inherit (partsArgs) self' inputs'; };

      documentation.enable = false;
      documentation.info.enable = false;
      documentation.doc.enable = false;
      documentation.man.enable = false;

      security.pki.certificateFiles = [ "${self}/assets/mitmproxy-ca-cert.pem" ];

      time.timeZone = "Asia/Shanghai";

      users.knownUsers = [ config.system.primaryUser ];
      users.users.${config.system.primaryUser} = {
        home = lib.mkDefault "/Users/${config.system.primaryUser}";
        uid = lib.mkDefault 501;
      };

      networking.wakeOnLan.enable = true;
      security.pam.services.sudo_local.touchIdAuth = true;

      system = {
        checks.verifyNixPath = false;
        primaryUser = lib.mkDefault "urie";
        startup.chime = false; # Disable the sound effects on boot
        activationScripts = {
          extraActivation.text =
            let
              user-extra = pkgs.writeShellScript "user-extra" ''
                # chflags nohidden ~/Library # Show the ~/Library folder
                ${pkgs.defaultbrowser}/bin/defaultbrowser browser # set arc as default browser

                # activateSettings -u will reload the settings from the database and apply them to the current session,
                # so we do not need to logout and login again to make the changes take effect.
                /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
              '';
            in
            # sh
            ''
              chflags nohidden /Volumes

              # if ! security find-certificate -c "mitmproxy" /Library/Keychains/System.keychain &>/dev/null; then
              #   echo "Installing certificate to System keychain..."
              #   sudo security add-trusted-cert -d -p ssl -p basic -k /Library/Keychains/System.keychain {mitmproxy-ca}
              # fi

              # run as user
              sudo -u ${config.system.primaryUser} ${user-extra}

              # disable spotlight
              launchctl unload -w /System/Library/LaunchDaemons/com.apple.metadata.mds.plist >/dev/null 2>&1 || true
              # disable fseventsd on /nix volume
              mkdir -p /nix/.fseventsd
              test -e /nix/.fseventsd/no_log || touch /nix/.fseventsd/no_log
            '';
        };
      };

      system.defaults = {
        universalaccess.reduceMotion = true; # 减少动画
        NSGlobalDomain = {
          "com.apple.swipescrolldirection" = pkgs.lib.mkDefault false; # enable natural scrolling(default to true)
          "com.apple.sound.beep.feedback" = 0; # disable beep sound when pressing volume up/down key
          "com.apple.mouse.tapBehavior" = 1;
          AppleInterfaceStyle = "Dark"; # dark mode
          AppleKeyboardUIMode = 3; # Enable full keyboard access for all controls
          ApplePressAndHoldEnabled = true; # enable press and hold
          KeyRepeat = 2;
          InitialKeyRepeat = 10; # Set a blazingly fast keyboard repeat rate
          NSAutomaticCapitalizationEnabled = false; # disable auto capitalization(自动大写)
          NSAutomaticDashSubstitutionEnabled = false; # disable auto dash substitution(智能破折号替换)
          NSAutomaticPeriodSubstitutionEnabled = false; # disable auto period substitution(智能句号替换)
          NSAutomaticQuoteSubstitutionEnabled = false; # disable auto quote substitution(智能引号替换)
          NSAutomaticSpellingCorrectionEnabled = false; # disable auto spelling correction(自动拼写检查)
          NSNavPanelExpandedStateForSaveMode = true; # expand save panel by default(保存文件时的路径选择/文件名输入页)
          NSNavPanelExpandedStateForSaveMode2 = true;
          NSTextShowsControlCharacters = true; # Display ASCII control characters using caret notation in standard text views
          # Enable subpixel font rendering on non-Apple LCDs
          # Reference: https://github.com/kevinSuttle/macOS-Defaults/issues/17#issuecomment-266633501
          AppleFontSmoothing = 1;
        };
        LaunchServices.LSQuarantine = false; # 关闭“从互联网下载的应用程序”隔离警告
        screensaver = {
          askForPassword = true; # Require password immediately after sleep or screen saver begins
          askForPasswordDelay = 0;
        };
        dock = {
          orientation = "bottom"; # 位置
          tilesize = 36; # 大小
          autohide = true; # 是否自动隐藏
          autohide-time-modifier = 0.0; # 自动隐藏动画时间
          autohide-delay = 0.0; # 自动隐藏后打开时间
          show-recents = false; # 显示最近内容
          mineffect = "scale"; # 最小化动画效果: genie(default) scale suck
          static-only = true; # 只显示活动的应用程序
          mru-spaces = false; # 根据最近使用自动重新排列空间
          expose-animation-duration = 0.1; # Speed up Mission Control animations
          expose-group-apps = false;
          dashboard-in-overlay = true; # Don’t show Dashboard as a Space
          # Hot corner action for top left corner. Valid values include:
          #
          # * `1`: Disabled
          # * `2`: Mission Control
          # * `3`: Application Windows
          # * `4`: Desktop
          # * `5`: Start Screen Saver
          # * `6`: Disable Screen Saver
          # * `7`: Dashboard
          # * `10`: Put Display to Sleep
          # * `11`: Launchpad
          # * `12`: Notification Center
          # * `13`: Lock Screen
          # * `14`: Quick Note
          wvous-tl-corner = 2;
          wvous-bl-corner = 11;
          wvous-tr-corner = 10;
          wvous-br-corner = 14;
        };
        screencapture = {
          disable-shadow = false; # 禁用阴影
          include-date = true; # 文件名是否包含日期
          location = "~/Pictures"; # 保存文件夹
          show-thumbnail = true; # 截图后显示缩略图
          type = "png"; # 文件格式
        };
        finder = {
          NewWindowTarget = "Home";
          _FXShowPosixPathInTitle = true; # Display full POSIX path as Finder window title
          QuitMenuItem = true; # 向 Finder 添加退出选项
          AppleShowAllExtensions = true; # 显示扩展名
          AppleShowAllFiles = true;
          FXEnableExtensionChangeWarning = false; # disable warning when changing file extension
          ShowPathbar = true;
          ShowStatusBar = true; # show status bar
          FXPreferredViewStyle = "clmv"; # 默认视图样式: clmv Nlsv glyv icnv
          _FXSortFoldersFirst = true; # 将文件夹保留在顶部
          ShowHardDrivesOnDesktop = false; # 在桌面上显示硬盘
          ShowExternalHardDrivesOnDesktop = true; # 在桌面上显示外部磁盘
          ShowRemovableMediaOnDesktop = true; # 显示可移动媒体
          ShowMountedServersOnDesktop = true; # 在桌面上显示连接的服务器
        };
        trackpad = {
          # tap - 轻触触摸板, click - 点击触摸板
          Clicking = true; # enable tap to click(轻触触摸板相当于点击)
          TrackpadRightClick = true; # enable two finger right click
          TrackpadThreeFingerDrag = true; # enable three finger drag
        };
        ActivityMonitor = {
          OpenMainWindow = true;
          IconType = 5; # Visualize CPU usage in the Activity Monitor Dock icon
          ShowCategory = 100; # Show all processes in Activity Monitor
          SortColumn = "CPUUsage"; # Sort Activity Monitor results by CPU usage
          SortDirection = 0;
        };
        CustomSystemPreferences = {
          "/Library/Preferences/com.apple.windowserver".DisplayResolutionEnabled = true; # Enable HiDPI display modes (requires restart)
        };
        loginwindow = {
          GuestEnabled = false; # disable guest user
          SHOWFULLNAME = true; # show full name in login window
        };
        CustomUserPreferences = {
          NSGlobalDomain = {
            NSToolbarTitleViewRolloverDelay = 0.0; # Adjust toolbar title rollover delay
            NSAutomaticCapitalizationEnabled = false; # Disable automatic capitalization as it’s annoying when typing code
            WebKitDeveloperExtras = true; # Add a context menu item for showing the Web Inspector in web views
          };
          "com.apple.systempreferences".NSQuitAlwaysKeepsWindows = false; # Disable Resume system-wide
          "com.apple.HIToolbox" = {
            AppleCapsLockPressAndHoldToggleOff = 0; # 短按大写锁定切换输入法
            AppleGlobalTextInputProperties.TextInputGlobalPropertyPerContextInput = 0; # 输入法自动调整
          };
          "com.apple.inputmethod.CoreChineseEngineFramework".shuangpinLayout = 4; # 小鹤双拼方案
          "com.apple.BluetoothAudioAgent"."Apple Bitpool Min (editable)" = 40; # Increase sound quality for Bluetooth headphones/headsets
          "com.apple.finder" = {
            AppleShowAllFiles = true;
            ShowExternalHardDrivesOnDesktop = true;
            ShowHardDrivesOnDesktop = true;
            ShowMountedServersOnDesktop = true;
            ShowRemovableMediaOnDesktop = true;
            _FXSortFoldersFirst = true;
            FXInfoPanesExpanded = {
              # Expand the following File Info panes:
              # “General”, “Open with”, and “Sharing & Permissions”
              General = true;
              OpenWith = true;
              Privileges = true;
            };
            DisableAllAnimations = true;
            FXDefaultSearchScope = "SCcf"; # 默认搜索范围 SCcf(当前文件夹)
            FXRemoveOldTrashItems = true; # 30天后清空垃圾箱
            FXEnableExtensionChangeWarning = false; # 更改文件扩展名警告
            NSDocumentSaveNewDocumentsToCloud = false; # 默认保存到磁盘或 iCloud

            _FXSortFoldersFirstOnDesktop = true; # 排序时将文件夹保留在顶部
            CreateDesktop = false; # 隐藏桌面上的所有图标
          };
          "com.apple.desktopservices" = {
            # Avoid creating .DS_Store files on network or USB volumes
            DSDontWriteNetworkStores = true;
            DSDontWriteUSBStores = true;
          };
          "com.apple.spaces" = {
            # Display have separate spaces
            #   true => disable this feature
            #   false => enable this feature
            "spans-displays" = false;
          };
          "com.apple.AdLib" = {
            allowApplePersonalizedAdvertising = false;
          };
          WindowManager = {
            EnableStandardClickToShowDesktop = false; # Click wallpaper to reveal desktop
            StandardHideDesktopIcons = false; # Show items on desktop
            HideDesktop = false; # Do not hide items on desktop & stage manager
            StandardHideWidgets = false;
            StageManagerHideWidgets = false;
          };
          controlcenter.BatteryShowPercentage = true;
          "com.apple.frameworks.diskimages" = {
            # Disable disk image verification
            skip-verify = true;
            skip-verify-locked = true;
            skip-verify-remote = true;
          };
          "com.apple.NetworkBrowser".BrowseAllInterfaces = true; # Enable AirDrop over Ethernet and on unsupported Macs running Lion
          "com.apple.dashboard".mcx-disabled = true; # Disable Dashboard
          "com.apple.dock" = {
            # shift: 131072 Control: 262144 option: 524288 cmd: 1048576
            wvous-tl-modifier = 1048576;
            wvous-tr-modifier = 1048576;
            wvous-bl-modifier = 1048576;
          };
          "com.apple.DiskUtility".DUDebugMenuEnabled = true; # Enable the debug menu in Disk Utility
          "com.apple.DiskUtility".advanced-image-options = true;
          "com.apple.QuickTimePlayerX".MGPlayMovieOnOpen = true; # Auto-play videos when opened with QuickTime Player
          "com.apple.appstore".WebKitDeveloperExtras = true; # Enable the WebKit Developer Tools in the Mac App Store
          "com.google.Chrome" = {
            AppleEnableSwipeNavigateWithScrolls = false; # Disable the all too sensitive backswipe on trackpads
            AppleEnableMouseSwipeNavigateWithScrolls = false; # Disable the all too sensitive backswipe on Magic Mouse
            DisablePrintPreview = true; # Use the system-native print preview dialog
            PMPrintingExpandedStateForPrint2 = true; # Expand the print dialog by default
            NSUserKeyEquivalents = {
              # ctrl=^  cmd=@ shift=$
              "搜索标签页..." = "@$f";
              "选择上一个标签" = "@j";
              "选择下一个标签" = "@l";
            };
          };
          "company.thebrowser.Browser" = {
            NSUserKeyEquivalents = {
              "Previous Tab" = "@j";
              "Next Tab" = "@l";
              "Next Space" = "@n";
              "Go Back" = "^o";
              "Go Forward" = "^i";
            };
          };
          "com.apple.appleseed.FeedbackAssistant".Autogather = false; # 提交报告时不要自动收集大文件
          "com.apple.ActivityMonitor".UpdatePeriod = 5; # 活动监视器更新其数据的频率（以秒为单位）
        };
      };
    };
}
