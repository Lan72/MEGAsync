#include "MacXLocalSocket.h"
#include "MacXLocalSocketPrivate.h"
#include "megaapi.h"
#import <Cocoa/Cocoa.h>

using namespace mega;
using namespace std;

MacXLocalSocket::MacXLocalSocket(MacXLocalSocketPrivate *clientSocketPrivate)
    : socketPrivate(clientSocketPrivate)
{
    socketPrivate->socket = this;
}

MacXLocalSocket::~MacXLocalSocket()
{
    delete socketPrivate;
}

qint64 MacXLocalSocket::readCommand(QByteArray *data)
{
    int currentPos = 0;
    if (!socketPrivate->buf.size())
    {
        return -1;
    }

    char opCommand = '\0';
    const char *ptr = socketPrivate->buf.constData();
    const char* end = ptr + socketPrivate->buf.size();

    if (ptr + sizeof(char) > end)
    {
        MegaApi::log(MegaApi::LOG_LEVEL_ERROR, "Error reading command from shell ext: Not op code");
        socketPrivate->buf.remove(0, socketPrivate->buf.size());
        return -1;
    }

    opCommand = *ptr;
    data->append(opCommand);
    ptr += sizeof(char);
    currentPos += sizeof(char);

    if (ptr + sizeof(char) > end || *ptr != ':')
    {
        MegaApi::log(MegaApi::LOG_LEVEL_ERROR, "Error reading command from shell ext: Not first separator");
        socketPrivate->buf.remove(0, socketPrivate->buf.size());
        return -1;
    }
    ptr += sizeof(char);
    currentPos += sizeof(char);

    if (ptr + sizeof(uint32_t) > end)
    {
        MegaApi::log(MegaApi::LOG_LEVEL_ERROR, "Error reading command from shell ext: Not command length");
        socketPrivate->buf.remove(0, socketPrivate->buf.size());
        return -1;
    }

    uint32_t commandLength;
    memcpy(&commandLength, ptr, sizeof(uint32_t));
    ptr += sizeof(uint32_t);
    currentPos += sizeof(uint32_t);

    if (ptr + sizeof(char) > end || *ptr != ':')
    {
        MegaApi::log(MegaApi::LOG_LEVEL_ERROR, "Error reading command from shell ext: Not second separator");
        socketPrivate->buf.remove(0, socketPrivate->buf.size());
        return -1;
    }
    ptr += sizeof(char);

    if (ptr + commandLength > end)
    {
        MegaApi::log(MegaApi::LOG_LEVEL_ERROR, "Error reading command from shell ext: file path too long");
        socketPrivate->buf.remove(0, socketPrivate->buf.size());
        return -1;
    }

    data->append(socketPrivate->buf.mid(currentPos, commandLength + 1)); // + 1 is to copy the ':' character from the source string
    socketPrivate->buf.remove(0, commandLength + 3 + sizeof(uint32_t)); // 3 = opCommand + 2 ':' separator characters

    MegaApi::log(MegaApi::LOG_LEVEL_DEBUG, QString::fromUtf8("Command from shell ext: %1")
                 .arg(QString::fromUtf8(data->constData(), data->size())).toUtf8().constData());

    return data->size();
}

qint64 MacXLocalSocket::writeData(const char *data, qint64 len)
{
    if (!len)
    {
        MegaApi::log(MegaApi::LOG_LEVEL_WARNING, "Skipping write of zero bytes");
        return -1;
    }

    @try
    {
        MegaApi::log(MegaApi::LOG_LEVEL_DEBUG, QString::fromUtf8("Sending data to shell ext: %1")
                     .arg(QString::fromUtf8(data, len)).toUtf8().constData());
        [socketPrivate->extClient send:[NSData dataWithBytes:(const void *)data length:sizeof(unsigned char)*len]];
        return len;
    }
    @catch(NSException *e)
    {
        emit disconnected();
        return -1;
    }
}
