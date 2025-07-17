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
          // 绑定到端口 7777
          ns.SandboxFinder.run(this.context, 7777).then((server: ESObject) => {
            if (server.address) {
              AppStorage.setOrCreate('server', `http://${server.address}:${server.port}`)
            }
          })
        });

        // 保持不息屏
        windowStage.getMainWindowSync().setWindowKeepScreenOn(true)
      }

    });
  }
}