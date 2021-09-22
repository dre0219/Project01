/*
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */

#define MAX 20

#include <Timer.h>
#include "includes/command.h"
#include "includes/packet.h"
#include "includes/CommandMsg.h"
#include "includes/sendInfo.h"
#include "includes/channels.h"

typedef struct Neighbor{
   uint16_t srcNode;
   uint16_t age;
} Neighbor;

module Node{
   uses interface Boot;

   uses interface SplitControl as AMControl;
   uses interface Receive;

   uses interface SimpleSend as Sender;

   uses interface CommandHandler;

   uses interface List<Neighbor> as NeighborList;
   uses interface List<pack> as PacketList;
   uses interface Timer<TMilli> as NeighborTimer;
   uses interface Random as Random;
}

implementation{
   pack sendPackage;
   uint16_t seqNumber = 0;

   // Prototypes
   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

   //Project 1 Prototypes
   void addPacket(pack Packet);
   void locateNeighbors();
   bool packageExists(pack* packet);
   bool neighborExists(uint16_t src);


   event void Boot.booted(){
      call AMControl.start();

      dbg(GENERAL_CHANNEL, "Booted\n");
   }

   event void AMControl.startDone(error_t err){
      if(err == SUCCESS){
         dbg(GENERAL_CHANNEL, "Radio On\n");
         call NeighborTimer.startPeriodic(1000); // initiates neighbor discovery at random intervals to avoid collision
      }else{
         //Retry until successful
         call AMControl.start();
      }
   }

   event void NeighborTimer.fired(){
      locateNeighbors(); //updates list of neighbors when the timer above goes off
   }

   event void AMControl.stopDone(error_t err){}

   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len){
      //dbg(GENERAL_CHANNEL, "Packet Received\n");
      if(len==sizeof(pack)){
         pack* myMsg=(pack*) payload;
         
         if(packageExists(myMsg) || myMsg->TTL == 0){ //drops the package if it already exists to avoid repeat
            dbg(FLOODING_CHANNEL, "dropping packet of seq#%d from %d\n", myMsg->seq, myMsg->src);
         }                                            //drops if TTL reaches 0 to avoid infinite loop
         else if(myMsg->dest == AM_BROADCAST_ADDR){
            Neighbor neighbor;

            switch(myMsg->protocol){
               case PROTOCOL_PING: //configure for neighbor discovery to send back to the sender
                 // dbg(NEIGHBOR_CHANNEL, "Received neighbor discovery packet, responding to node %d\n", myMsg->src);
                  makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, MAX_TTL, PROTOCOL_PINGREPLY, 
                     myMsg->seq, (uint8_t *) myMsg->payload, sizeof(myMsg->payload));
                  addPacket(sendPackage); //packages a ping reply with own id and sends it back to sender
                  call Sender.send(sendPackage, myMsg->src);
                  break;

               case PROTOCOL_PINGREPLY:
                  //if neighbor exists but not found, add to list
                  if(!neighborExists(myMsg->src)){
                     //dbg(NEIGHBOR_CHANNEL, "node %d not found so adding to list\n", myMsg->src);
                     neighbor.srcNode = myMsg->src; //creates neighbor struct
                     neighbor.age = 0;
                     call NeighborList.pushback(neighbor); //adds neighbor to list
                  }
                  break;

               default:
                  break;
            }
         }
         else if(myMsg->dest == TOS_NODE_ID){
            //dbg(FLOODING_CHANNEL, "Package Payload: %s, source: %d, destination: %d\n", myMsg->payload, myMsg->src, myMsg->dest);
            switch(myMsg->protocol){
               case PROTOCOL_PING: //package received, arrived at destination, sends a packet to notify source node of arrival
                  dbg(FLOODING_CHANNEL, "Sending Ping Reply to %d! \n", myMsg->src);
                  makePack(&sendPackage, TOS_NODE_ID, myMsg->src, myMsg->TTL-1,
                        PROTOCOL_PINGREPLY, seqNumber, (uint8_t *) myMsg->payload, sizeof(myMsg->payload)); //flips the src and dest values
                  seqNumber++;

                  //dbg(FLOODING_CHANNEL, "Package Payload: %s, source: %d, destination: %d\n", sendPackage.payload, sendPackage.src, sendPackage.dest);
                  addPacket(sendPackage);
                  call Sender.send(sendPackage, AM_BROADCAST_ADDR);
                  break;

					case PROTOCOL_PINGREPLY:
					   dbg(FLOODING_CHANNEL, "Received a Ping %d!\n", myMsg->src); //notifies us that the source got the reply packet
					break;

               default:
               break;
            } 
         }
         else {
            //If the destination is not reached, send packet to all neighbors. decrement the TTL
            makePack(&sendPackage, myMsg->src, myMsg->dest, myMsg->TTL-1, myMsg->protocol, myMsg->seq, 
               (uint8_t *)myMsg->payload, sizeof(myMsg->payload));
            dbg(FLOODING_CHANNEL, "Received Message from %d meant for %d\n", myMsg->src, myMsg->dest);
            addPacket(sendPackage);
            call Sender.send(sendPackage, AM_BROADCAST_ADDR);
         }
         //dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload);
         return msg;
         
      }
      
      dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
      return msg;
   }


   event void CommandHandler.ping(uint16_t destination, uint8_t *payload){
      dbg(GENERAL_CHANNEL, "PING EVENT \n");
      makePack(&sendPackage, TOS_NODE_ID, destination, MAX_TTL, PROTOCOL_PING, seqNumber, payload, PACKET_MAX_PAYLOAD_SIZE);
      call Sender.send(sendPackage, AM_BROADCAST_ADDR);
   }

   event void CommandHandler.printNeighbors(){
      uint16_t i;
      uint16_t size = call NeighborList.size();
      Neighbor temp;
      if(size == 0){
         dbg(NEIGHBOR_CHANNEL, "No neighbors found in list\n");
      }
      else{
         //dbg(NEIGHBOR_CHANNEL, "Dumping NeighborList of size %d\n", size);
         for(i = 0; i < size; i++){
            temp = call NeighborList.get(i);
            dbg(NEIGHBOR_CHANNEL, "Neighbor: %d, Age: %d\n", temp.srcNode, temp.age);
         }
      }
   }

   event void CommandHandler.printRouteTable(){}

   event void CommandHandler.printLinkState(){}

   event void CommandHandler.printDistanceVector(){}

   event void CommandHandler.setTestServer(){}

   event void CommandHandler.setTestClient(){}

   event void CommandHandler.setAppServer(){}

   event void CommandHandler.setAppClient(){}

   void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length){
      Package->src = src;
      Package->dest = dest;
      Package->TTL = TTL;
      Package->seq = seq;
      Package->protocol = protocol;
      memcpy(Package->payload, payload, length);
   }

   //Project 1 functions

   void addPacket(pack Package){
      call PacketList.pushback(Package); //adds packet to front of list
   }

   bool packageExists(pack* packet){
      uint16_t i;
      pack temp;
      for(i = 0; i < call PacketList.size(); i++){
         temp = call PacketList.get(i);
         if(temp.src == packet-> src && temp.dest == packet->dest && temp.seq == packet->seq && temp.protocol == packet->protocol){ //if the src,des,and seq are the same, then the packet already exists
            return TRUE;
         }
      }
      return FALSE;
   }

   bool neighborExists(uint16_t src){
      if(!call NeighborList.isEmpty()){
         uint16_t i; 
         uint16_t size = call NeighborList.size();
         Neighbor temp;
         for(i = 0; i < size; i++){
            temp = call NeighborList.get(i);
            if(temp.srcNode == src){
               //dbg(NEIGHBOR_CHANNEL, "updating node %d in list\n", src);
               temp.age = 0;
               return TRUE;
            }
         }
      }
      return FALSE;
   }

   void locateNeighbors(){
      char* message = "Nepnep\n"; 
      Neighbor temp;
      uint16_t i;
      uint16_t size = call NeighborList.size();

      if(!call NeighborList.isEmpty()){
         //dbg(NEIGHBOR_CHANNEL, "%d checking list for neighbors\n", TOS_NODE_ID);
         for(i = 0; i < size; i++){ //increase age with each neighbor discovery call
            temp = call NeighborList.get(i);
            temp.age++;
            call NeighborList.remove(i);
            call NeighborList.pushback(temp);
         }
         for(i = 0; i < size; i++){
            temp = call NeighborList.get(i);
            if(temp.age > 5){
               //dbg(NEIGHBOR_CHANNEL, "Node %d over age 5\n", temp.srcNode);
               temp = call NeighborList.remove(i); //removes the neighbor and place in pool for use if neighbor found
               size--; //adjusting size of list reflect change
               i--;
            }
         }
      }

      //Create a packet that is sent to all neighbors as a ping
      makePack(&sendPackage, TOS_NODE_ID, AM_BROADCAST_ADDR, 2, PROTOCOL_PING, 1, (uint8_t *)message,(uint8_t)sizeof(message));
      addPacket(sendPackage);
      call Sender.send(sendPackage, AM_BROADCAST_ADDR);
   }
}
