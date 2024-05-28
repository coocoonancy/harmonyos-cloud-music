import AvSession from '@ohos.multimedia.avsession'
import { songItemType } from '../models'
import { AvPlayerManager } from './AvPlayerManager'

export default class AvSessionManager {
  static session: AvSession.AVSession
  static controller: AvSession.AVSessionController

  // 初始化媒体会话
  static async init(context: Context) {
    AvSessionManager.session = await AvSession.createAVSession(context, 'bgPlay', 'audio') // 拿到会话对象
    AvSessionManager.controller = await AvSessionManager.session.getController() // 拿到会话控制器
    AvSessionManager.registerEvent()
  }

  // 设置媒体资源
  static async setAvMetaData(song: songItemType) {
    await AvSessionManager.session.setAVMetadata({
      assetId: song.id,
      title: song.name,
      artist: song.author,
      mediaImage: song.img,
      duration: AvPlayerManager.currentSong.duration
    })
  }

  // 设置状态方法
  static async setAVPlaybackState() {
    AvSessionManager.session.setAVPlaybackState({
      state: AvPlayerManager.currentSong.isPlay ? AvSession.PlaybackState.PLAYBACK_STATE_PLAY :
      AvSession.PlaybackState.PLAYBACK_STATE_PAUSE,
      position: {
        elapsedTime: AvPlayerManager.currentSong.time,
        updateTime: (new Date()).getTime(),
      },
      speed: 1.0,
      duration: AvPlayerManager.currentSong.duration
    })
  }

  static async registerEvent() {
    AvSessionManager.session.on('play', () => {
      AvPlayerManager.singlePlay(AvPlayerManager.currentSong.playList[AvPlayerManager.currentSong.playIndex])
    })
    AvSessionManager.session.on('pause', () => {
      AvPlayerManager.pause()
    })
    AvSessionManager.session.on('stop', () => {
    })
    AvSessionManager.session.on('playNext', () => {
      AvPlayerManager.nextPlay()
    })
    AvSessionManager.session.on('playPrevious', () => {
      AvPlayerManager.prevPlay()
    })
    AvSessionManager.session.on('seek', (time) => {
      AvPlayerManager.player!.seek(time)
    })
    AvSessionManager.session.activate()
  }
}