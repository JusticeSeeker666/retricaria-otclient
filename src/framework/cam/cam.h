#ifndef __CAM_H__
#define __CAM_H__


#include "camdeclaration.h"
#include <framework/luaengine/luaobject.h>
#include <framework/luaengine/luainterface.h>
#include <framework/core/filestream.h>
#include <framework/net/protocol.h>
#include <framework/core/resourcemanager.h>
#include <framework/core/clock.h>
#include <client/protocolgame.h>
#include <client/game.h>
#include <framework/core/eventdispatcher.h>
#include <framework/stdext/thread.h>

class CAMFrame : public LuaObject
{
public:
  bool readPacket(const FileStreamPtr& fin){
    try{
        if (!fin){
          stdext::throw_exception("Error: FileStreamPtr not found");
          return false;
        }

        uint8_t packetCode = fin->getU8();
        if (packetCode != 255){
          stdext::throw_exception(stdext::format("Error: FileStreamPtr packetCode = %d", packetCode));
          return false;
        }

        id = fin->getU32();
        time = fin->getU32();
        uint16_t msgSize = fin->getU16();
        uint8* data = new uint8[msgSize];
        fin->read(&data[0], msgSize);
        msg = OutputMessagePtr(new OutputMessage);
        msg->addBuffer(msgSize, &data[0]);
        delete data;

    }catch(stdext::exception& e) {
      g_logger.error(stdext::format("Error in readFrame: %s", e.what()));
      return false;
    }

    return true;
  }

  OutputMessagePtr getMsg() { return msg; }
  uint32_t getTime() { return time; }
  uint32_t getId() { return id; }

  OutputMessagePtr msg;
  uint32_t time = 0;
  uint32_t id = 0;
};

class CAM : public LuaObject
{

public:
  CAM();
  bool isRecording(){return m_recording;}
  bool startRecording(const std::string& fileName);
  std::string stopRecording();
  void writeMessage(const InputMessagePtr& msg);
  uint32_t getDuration(){return m_duration;}
  std::vector<CAMFramePtr> getFrames(){return m_frames;}
  bool isPlaying(){return m_playing;}
  bool preparePlaying(const std::string& fileName);
  bool startPlaying();
  void stopPlaying();
  void myloop();
  bool canReadFrame();
  int readFrames(int n);

private:
  std::mutex m_mutex;
  bool m_recording = false;
  uint32_t m_writePacketCounter = 0;
  uint32_t m_readPacketCounter = 0;
  ticks_t m_startedTime;
  FileStreamPtr m_fin;
  uint8_t m_camPacketCode = 255;
  uint32_t m_duration = 0;
  bool m_playing = false;
  std::vector<CAMFramePtr> m_frames;
  uint16_t m_version = 0;

};

extern CAM g_cam;
#endif
