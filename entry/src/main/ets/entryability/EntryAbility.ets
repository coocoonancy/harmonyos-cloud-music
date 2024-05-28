import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { SONG_KEY } from '../constants';
import { AvPlayerManager } from '../utils/AvPlayerManager';
import AvSessionManager from '../utils/AvSessionManager';
import FormIdManager from '../utils/FormIdManager';
import { rpc } from '@kit.IPCKit';
import SongManager from '../utils/SongManager';

class Params implements rpc.Parcelable {
  marshalling(messageSequence: rpc.MessageSequence): boolean {
    return true;
  }

  unmarshalling(messageSequence: rpc.MessageSequence): boolean {
    return true;
  }
}

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onCreate');
    AvPlayerManager.init()
    AvSessionManager.init(this.context)

    class ParamsForm {
      formId: string = ""
    }

    this.callee.on("getFormId", (data) => {
      const res = JSON.parse(data.readString()) as ParamsForm
      FormIdManager.addFormId(res.formId).then(() => {
        AvPlayerManager.pushImg() // 硬推一次
      }) // 加入formId
      // 先推一次
      // formProvider.updateForm(res.formId, formBindingData.createFormBindingData({
      //   song: AvPlayerManager.currentSong // 当前歌曲推过去
      // }))
      return new Params() // 只是为了不报错
    })
    this.callee.on("prev", (data) => {
      AvPlayerManager.prevPlay()
      return new Params() // 只是为了不报错
    })
    this.callee.on("next", (data) => {
      AvPlayerManager.nextPlay()
      return new Params() // 只是为了不报错
    })
  }

  onDestroy(): void {
    this.callee.off("prev")
    this.callee.off("next")
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    const win = await windowStage.getMainWindow()
    win.setWindowLayoutFullScreen(true)
    AppStorage.setOrCreate("topHeight", px2vp(win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM)
      .topRect.height))
    AppStorage.setOrCreate("bottomHeight", px2vp(win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR)
      .bottomRect.height))
    const childWin = await windowStage.createSubWindow("ad_win") // 创建广告子窗口
    await childWin.showWindow()
    await childWin.setUIContent("pages/Start/Start")
    FormIdManager.context = this.context
    const currentSong = await SongManager.getSong()
    currentSong.isPlay = false
    AvPlayerManager.currentSong = currentSong
    if (AvPlayerManager.currentSong.url) {
      AvPlayerManager.player!.url = AvPlayerManager.currentSong.url
      AppStorage.setOrCreate('firstPlay', 1)
    }
    AppStorage.setOrCreate(SONG_KEY, AvPlayerManager.currentSong)
    windowStage.loadContent("pages/Index/Index")
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
