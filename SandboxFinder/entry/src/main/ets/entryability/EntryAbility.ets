import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';


export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);

    import('sandboxfinder').then((ns: ESObject) => {
      // 绑定到端口 7777
      ns.SandboxFinder.start(this.context, 7777)
    });
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        return;
      }
    });
    // 保持不息屏
    windowStage.getMainWindowSync().setWindowKeepScreenOn(true)
  }
}