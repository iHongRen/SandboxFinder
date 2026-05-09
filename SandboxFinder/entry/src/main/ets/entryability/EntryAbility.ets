import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import BuildProfile from 'BuildProfile';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        return;
      }

      if (BuildProfile.DEBUG) {
        import('@cxy/sandboxfinder').then(async (ns: ESObject) => {
          // 默认配置启动
          ns.SandboxFinder.run().then((server: ESObject) => {
            if (server.address) {
              AppStorage.setOrCreate('server', `http://${server.address}:${server.port}`)
            }
          })

          /**
           * 详细 SandboxFinder 启动配置
           */
          // export interface SandboxFinderOptions {
          //   /** 监听端口，默认 7777 */
          //   port?: number;
          //   /** 监听地址，默认自动获取本机 IP */
          //   address?: string;
          //   /** 根目录，默认 '/' 展示全部沙箱目录。传入具体路径则只暴露该目录，如 context.filesDir */
          //   rootDir?: string;
          //   /** UIAbilityContext，默认自动获取 */
          //   context?: common.UIAbilityContext;
          //   /** 是否显示侧边栏，默认 true。设为 false 时整个侧边栏隐藏 */
          //   showSidebar?: boolean;
          //   /** 是否显示侧边栏中的"应用信息"区块，默认 true */
          //   showAppInfo?: boolean;
          //   /** 是否显示侧边栏中的"关于"区块，默认 true */
          //   showAbout?: boolean;
          // }

          // const context = windowStage.getMainWindowSync().getUIContext().getHostContext()
          // const rootDir = context?.cacheDir
          // ns.SandboxFinder.run({
          //   port: 19990,
          //   rootDir: rootDir,
          //   context: context,
          //   showSidebar: true,
          //   showAppInfo: true,
          //   showAbout: false,
          // }).then((server: ESObject) => {
          //   if (server.address) {
          //     AppStorage.setOrCreate('server', `http://${server.address}:${server.port}`)
          //   }
          // })

        });

        // 保持不息屏
        windowStage.getMainWindowSync().setWindowKeepScreenOn(true)
      }

    });
  }

  onWindowStageDestroy(): void {
    if (BuildProfile.DEBUG) {
      import('@cxy/sandboxfinder').then(async (ns: ESObject) => {
        ns.SandboxFinder.stop()
      })
    }
  }
}