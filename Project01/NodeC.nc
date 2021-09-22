/**
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */

#include <Timer.h>
#include "includes/CommandMsg.h"
#include "includes/packet.h"

configuration NodeC{
}
implementation {
    components MainC;
    components Node;
    components new AMReceiverC(AM_PACK) as GeneralReceive;
    components new TimerMilliC() as NeighborTimerC;

    Node -> MainC.Boot;

    Node.NeighborTimer -> NeighborTimerC;

    Node.Receive -> GeneralReceive;

    components ActiveMessageC;
    Node.AMControl -> ActiveMessageC;

    components new SimpleSendC(AM_PACK);
    Node.Sender -> SimpleSendC;

    components CommandHandlerC;
    Node.CommandHandler -> CommandHandlerC;

    components new ListC(Neighbor, 64) as NeighborC;
    Node.NeighborList -> NeighborC;

    components new ListC(pack, 64) as PacketC;
    Node.PacketList -> PacketC;

    components RandomC as Random;
    Node.Random -> Random;
}
