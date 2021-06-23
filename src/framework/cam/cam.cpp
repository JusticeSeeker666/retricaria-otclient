/*
print(g_cam.startRecording("teste.cam"))
g_cam.stopRecording()

print(g_cam.preparePlaying("teste.cam"))
print(g_cam.startPlaying())
print(g_cam.stopPlaying())
*/

#include "cam.h"

CAM g_cam;

CAM::CAM()
{
    m_recording = false;
    m_writePacketCounter = 0;
    m_startedTime = 0;
}

bool CAM::startRecording(const std::string& fileName)
{
    if (isRecording() || isPlaying())
    {
        return false;
    }

    if (fileName.empty())
    {
        return false;
    }
    m_writePacketCounter = 0;
    m_startedTime = g_clock.millis();
    m_fin = g_resources.createFile(fileName);
    if (!m_fin)
    {
        return false;
    }
    m_fin->addU16(1); //versao
    m_fin->addU32(0);
    m_recording = true;
    return true;
}

std::string CAM::stopRecording()
{
    if (!isRecording())
    {
        return std::string("not");
    }
    std::string fileName = m_fin->name();
    if (m_writePacketCounter == 0)
    {
        m_recording = false;
        m_fin->flush();
        m_fin->close();
        m_fin = nullptr;
        g_resources.deleteFile(fileName);
        return std::string("not");
    }
    uint64_t longDuration = (uint64_t) (g_clock.millis() - m_startedTime);
    uint32_t duration = (uint32_t) (longDuration & 0xFFFFFFFF);
    m_fin->seek(2);
    m_fin->addU32(duration);
    m_recording = false;
    m_fin->flush();
    m_fin->close();
    m_fin = nullptr;
    return fileName;
}

void CAM::writeMessage(const InputMessagePtr& msg)
{
    m_mutex.lock();
    if (!isRecording())
    {
        return;
    }
    if (isPlaying())
    {
        return;
    }
    if (!m_fin)
    {
        return;
    }

    uint16_t msgSize = msg->getUnreadSize();
    uint64_t longPacketTime = (uint64_t) (g_clock.millis() - m_startedTime);
    uint32_t packetTime = (uint32_t) (longPacketTime & 0xFFFFFFFF);
    m_fin->addU8(m_camPacketCode);
    m_fin->addU32(m_writePacketCounter++); //id of cam frame
    m_fin->addU32(packetTime);
    m_fin->addU16(msgSize);

    m_fin->write(msg->getReadBuffer(), msgSize);
    m_mutex.unlock();
}

bool CAM::preparePlaying(const std::string& fileName)
{
    if(isRecording() || isPlaying())
    {
        return false;
    }

    if (fileName.empty())
    {
        return false;
    }

    m_fin = g_resources.openFile(fileName);
    if (!m_fin)
    {
        return false;
    }

    if (m_frames.size() > 0)
    {
        m_frames.clear();
    }

    m_version = m_fin->getU16();
    m_duration = m_fin->getU32();
    m_playing = true;
    return true;
}

bool CAM::canReadFrame()
{
    if (!m_fin)
    {
        return false;
    }
    if (m_fin->eof())
    {
        return false;
    }
    return true;
}

int CAM::readFrames(int n)
{
    if (n == 0){return 0;}

    if (!canReadFrame())
    {
        return 0;
    }

    if (m_frames.size() > 0)
    {
        m_frames.clear();
    }

    int i = 1;
    while(i <= n && !m_fin->eof()){
        CAMFramePtr frame = CAMFramePtr(new CAMFrame);
        if (frame->readPacket(m_fin))
        {
            m_frames.push_back(frame);
        }
        else
        {
            g_logger.error("Error ao ler frame");
            return 0;
        }
        i = i + 1;

    }
    return i;
}

bool CAM::startPlaying()
{
    if(!isPlaying())
    {
        return false;
    }
    /*
    if(m_frames.size() == 0)
    {
        return false;
    }*/

    return true;
}

void CAM::stopPlaying()
{
    if(!isPlaying())
    {
        return;
    }
    m_frames.clear();
    m_playing = false;
    m_fin->close();
    m_fin = nullptr;
    m_readPacketCounter = 0;
}
