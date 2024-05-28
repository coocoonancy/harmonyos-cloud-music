import media from '@ohos.multimedia.media'
import { SONG_KEY } from '../constants'
import { PlayStateType, songItemType } from '../models'
import { router } from '@kit.ArkUI'
import { wantAgent } from '@kit.AbilityKit'
import AvSessionManager from './AvSessionManager'
import { backgroundTaskManager } from '@kit.BackgroundTasksKit'
import FormIdManager from './FormIdManager'
import { formBindingData, formProvider } from '@kit.FormKit'
import ImageSave from './ImageSave'
import { fileIo } from '@kit.CoreFileKit'

export class AvPlayerManager {
  static player: media.AVPlayer | null = null
  static currentSong: PlayStateType = new PlayStateType() // 当前歌曲的状态

  static async init() {
    if (!AvPlayerManager.player) {
      AvPlayerManager.player = await media.createAVPlayer()
    }
    AvPlayerManager.player.on("stateChange", (state) => {
      switch (state) {
        case "initialized":
          AvPlayerManager.player?.prepare() // 准备
          break;
        case "prepared":
          if (AppStorage.get('firstPlay') === 1) {
            AppStorage.setOrCreate("firstPlay", 0)
          } else {
            AvPlayerManager.currentSong.isPlay = true
            AvPlayerManager.player?.play() // 播放
          }
          break;
        case "completed":
          AvPlayerManager.nextPlay(AvPlayerManager.currentSong.playMode === "repeat")
          break;
      }
    })
    //  监听歌曲时长
    AvPlayerManager.player.on('durationUpdate', (duration) => {
      // 每次切换歌曲都会触发这个函数，更新即可
      AvPlayerManager.currentSong.duration = duration
      AppStorage.setOrCreate<PlayStateType>(SONG_KEY, AvPlayerManager.currentSong) // 更新全局状态
      AvSessionManager.setAvMetaData(AvPlayerManager.currentSong.playList[AvPlayerManager.currentSong.playIndex])
    })
    //  监听播放时长
    AvPlayerManager.player.on('timeUpdate', (time) => {
      AvPlayerManager.currentSong.time = time
      AppStorage.setOrCreate<PlayStateType>(SONG_KEY, AvPlayerManager.currentSong) // 更新全局状态
      AvSessionManager.setAVPlaybackState()
    })
  }


  // 点击某个歌曲播放
  // 单首歌播放
  static singlePlay(song: songItemType) {
    AvPlayerManager.startBackgroundTask()
    // 添加到播放列表中，再进行播放
    const isList = AvPlayerManager.currentSong.playList.some((item: songItemType) => item.id === song.id)
    if (isList) {
      // 是不是正在播放的
      if (AvPlayerManager.player!.url === song.url) {
        // 重新播放（切换当前播放索引的歌曲）
        // 如果是同一首 则继续播放
        AvPlayerManager.player?.play()
        AvPlayerManager.currentSong.isPlay = true
      } else {
        // 切换歌曲(更新播放索引切换歌曲)
        AvPlayerManager.currentSong.playIndex = AvPlayerManager.currentSong.playList.findIndex((item: songItemType) => item.id === song.id)
        AvPlayerManager.changePlay()
      }
    } else {
      AvPlayerManager.currentSong.playList.unshift(song)
      AvPlayerManager.currentSong.playIndex = 0
      AvPlayerManager.changePlay()
    }
    AppStorage.setOrCreate<PlayStateType>(SONG_KEY, AvPlayerManager.currentSong) // 更新全局状态
    AvSessionManager.setAVPlaybackState()
  }

  // 切换歌曲
  static async changePlay() {
    // 重置播放器状态至初始化,异步方法
    await AvPlayerManager.player!.reset()
    // 重置播放状态
    AvPlayerManager.currentSong.duration = 0
    AvPlayerManager.currentSong.time = 0
    AvPlayerManager.player!.url = AvPlayerManager.currentSong.playList[AvPlayerManager.currentSong.playIndex].url
    AvPlayerManager.currentSong.img = AvPlayerManager.currentSong.playList[AvPlayerManager.currentSong.playIndex].img
    AvPlayerManager.currentSong.name = AvPlayerManager.currentSong.playList[AvPlayerManager.currentSong.playIndex].name
    AvPlayerManager.currentSong.author = AvPlayerManager.currentSong.playList[AvPlayerManager.currentSong.playIndex].author
    AvPlayerManager.currentSong.url = AvPlayerManager.currentSong.playList[AvPlayerManager.currentSong.playIndex].url


    // const formIdList = FormIdManager.getFormIdList()
    // formIdList.forEach(formId => {
    //   formProvider.updateForm(formId, formBindingData.createFormBindingData({
    //     song: AvPlayerManager.currentSong
    //   }))
    // })

    AvPlayerManager.pushImg()

  }


  // 暂停播放
  static pause() {
    AvPlayerManager.player!.pause()
    // 更新播放器状态
    AvPlayerManager.currentSong.isPlay = false
    AppStorage.set<PlayStateType>(SONG_KEY, AvPlayerManager.currentSong) // 更新到
    AvSessionManager.setAVPlaybackState()
  }

  // 上一首
  static prevPlay() {
    // 如果是随机播放
    if (AvPlayerManager.currentSong.playMode === "random" && AvPlayerManager.currentSong.playList.length) {
      AvPlayerManager.currentSong.playIndex = Math.floor(Math.random() * AvPlayerManager.currentSong.playList.length)
    } else {
      AvPlayerManager.currentSong.playIndex--
      // 有可能减到负数
      AvPlayerManager.currentSong.playIndex =
        (AvPlayerManager.currentSong.playIndex + AvPlayerManager.currentSong.playList.length) %
        AvPlayerManager.currentSong.playList.length
    }
    AvPlayerManager.singlePlay(AvPlayerManager.currentSong.playList[AvPlayerManager.currentSong.playIndex])
  }

  // 下一首
  static nextPlay(repeat?: boolean) {
    if (!AvPlayerManager.currentSong.playList.length) {
      return
    }
    if (!repeat) {
      if (AvPlayerManager.currentSong.playMode === "random" && AvPlayerManager.currentSong.playList.length) {
        AvPlayerManager.currentSong.playIndex = Math.floor(Math.random() * AvPlayerManager.currentSong.playList.length)
      } else {
        AvPlayerManager.currentSong.playIndex++
        // 有可能减到负数
        AvPlayerManager.currentSong.playIndex =
          (AvPlayerManager.currentSong.playIndex + AvPlayerManager.currentSong.playList.length) %
          AvPlayerManager.currentSong.playList.length
      }
    }

    AvPlayerManager.singlePlay(AvPlayerManager.currentSong.playList[AvPlayerManager.currentSong.playIndex])
  }

  // 删除播放
  static async remove(index: number) {
    if (AvPlayerManager.currentSong.playIndex === index) {
      // 是否删除正在播放的歌曲
      if (AvPlayerManager.currentSong.playList.length > 1) {
        // 如果当前的歌曲列表超过两个
        AvPlayerManager.currentSong.playList.splice(index, 1)
        AvPlayerManager.currentSong.playIndex = (AvPlayerManager.currentSong.playIndex + AvPlayerManager.currentSong.playList.length) % AvPlayerManager.currentSong.playList.length
        AvPlayerManager.singlePlay(AvPlayerManager.currentSong.playList[AvPlayerManager.currentSong.playIndex])
      } else {
        await AvPlayerManager.player!.reset()
        AvPlayerManager.currentSong = new PlayStateType() // 重置数据
        router.back()
      }

    } else {
      // 如果不是
      if (AvPlayerManager.currentSong.playIndex > index) {
        AvPlayerManager.currentSong.playIndex--
      }
      AvPlayerManager.currentSong.playList.splice(index, 1)
    }
    AppStorage.setOrCreate<PlayStateType>(SONG_KEY, AvPlayerManager.currentSong) // 更新全局状态

  }

  // 开启后台任务
  static async startBackgroundTask() {
    if (AvSessionManager.session.sessionId) {
      // 如果有会话id 则不用开启后台任务
      return
    }
    try {
      let wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [
          {
            bundleName: "com.coocoonancy.cloudmusic",
            abilityName: "EntryAbility"
          }
        ],
        operationType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      const want = await wantAgent.getWantAgent(wantAgentInfo) // 获取want信息
      await backgroundTaskManager.startBackgroundRunning(getContext(),
        backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK,
        want)
    } catch (error) {
      // 错误消息
      AlertDialog.show({ message: error.message })
    }

  }

  static async pushImg() {
    ImageSave.saveFile(AvPlayerManager.currentSong.name + ".jpg", AvPlayerManager.currentSong.img, async (filePath) => {
      AvPlayerManager.currentSong.cacheImg = filePath
      const formIdList = FormIdManager.getFormIdList()
      let fileInfo: Record<string, string | number> = {}
      let temFile = fileIo.openSync(AvPlayerManager.currentSong.cacheImg)
      fileInfo[AvPlayerManager.currentSong.cacheImg!] = temFile.fd
      const data = formBindingData.createFormBindingData({
        song: AvPlayerManager.currentSong,
        fileName: AvPlayerManager.currentSong.cacheImg,
        formImages: fileInfo
      })
      let index = 0
      while (index < formIdList.length) {
        await formProvider.updateForm(formIdList[index], data) // 更新数据
        index++
      }
    })
  }
}
