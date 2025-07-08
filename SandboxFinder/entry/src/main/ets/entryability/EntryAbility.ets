import { AbilityConstant, common, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { fileIo , Filter, ListFileOptions } from '@kit.CoreFileKit';
import { SandboxFinder } from 'sandboxfinder';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {


  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
    SandboxFinder.start(this.context, 7777)

    // console.error('cacheDir:' + this.context.cacheDir)
    // console.error('filesDir:' + this.context.filesDir)
    // console.error('preferencesDir:' + this.context.preferencesDir)
    // console.error('databaseDir:' + this.context.databaseDir)
    // console.error('tempDir:' + this.context.tempDir)
    // console.error('bundleCodeDir:' + this.context.bundleCodeDir)
    // console.error('resourceDir:' + this.context.resourceDir)
    //
    // this.getListFile(this.context)
  }

   getListFile(context: common.UIAbilityContext): void {
     let listFileOption: ListFileOptions = {
       recursion: true,
       listNum: 0,
       // filter: {
       //   suffix: [".png", ".jpg", ".txt"],
       //   displayName: ["test*"],
       //   fileSizeOver: 0,
       //   lastModifiedAfter: new Date(0).getTime()
       // }
     };
     let filesDir = this.context.distributedFilesDir // '/data/storage/el1/distributedfiles/';
     let files = fileIo.listFileSync(filesDir, listFileOption);
     for (let i = 0; i < files.length; i++) {
       console.error(`The name of file: ${files[i]}`);
     }
   }

  async onDestroy() {
    await SandboxFinder.stop()
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}