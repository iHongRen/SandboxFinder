import { AbilityConstant, common, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { fileIo, Filter, ListFileOptions } from '@kit.CoreFileKit';
import { SandboxFinder } from 'sandboxfinder';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);

    // 绑定到端口 7777
    SandboxFinder.start(this.context, 7777)
  }

  async onDestroy() {
    // 销毁时 stop
    await SandboxFinder.stop()
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