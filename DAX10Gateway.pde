/*
  DAX10Gateway
 
 A simple web server that relays X10 commands to the X10Firecracker Serial Device.
 using an Arduino Wiznet Ethernet shield. 
 
 Circuit:
 * Ethernet shield attached to pins 10, 11, 12, 13 - Digital
 * Firecracker attached to pins 2,3, GND - Digital
 
 created 21 Jan 2011
 by Donn O'Malley
 
 */

#include <SPI.h>
#include <Ethernet.h>
#include <X10Firecracker.h>

//Global Constants
const boolean DEBUG_MODE = true;
const boolean CLIENT_DEBUG = false;
const String MAC_STRING = "DE:AD:BE:EF:FE:ED";
const String IP_STRING = "192.1681.1.177";
const char COMMAND_CHARACTER = '?';
const int A = 65;
const int ZERO = 48;
const int ALL_UNITS = 42; //'*' CHARACTER
const int ALL_ROOMS = 42; //'*' CHARACTER
const HouseCode HouseCodeEnums[] = { hcA, hcB, hcC, hcD, hcE, hcF, hcG, hcH, hcI, hcJ, hcK, hcL, hcM, hcN, hcO, hcP}; //Matches X10Firecracker
const int UnitCodeEnums[] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16}; //Matches to X10Firecracker values
const CommandCode CommandCodeEnums[] = { cmdOn, cmdOff, cmdBright, cmdDim }; //Matches X10Firecracker

// Initialize the MAC/IP to use for the Arduino on the LAN
byte mac[] = { 0xDE, 0xAD, 0xBE, 0xEF, 0xFE, 0xED };
byte ip[] = { 192,168,1, 177 };
Server BrowserServer(8080); //Initialize Ethernet Server to HTTP Port 8080
Server AndroidServer(80); //Initialize Ethernet Server to HTTP Port 80
boolean AndroidClient;

void setup()
{
  //Initialize the Serial
  Serial.begin(9600);
  if(DEBUG_MODE) {
    Serial.println("Serial...Initialized");
  }
  
  // start the Ethernet connection and the server:
  Ethernet.begin(mac, ip);
  if(DEBUG_MODE) {
    Serial.print("Ethernet...Initialized :: ");
    Serial.print(IP_STRING + ' ');
    Serial.println('[' + MAC_STRING + ']');
  }
  
  BrowserServer.begin();
  if(DEBUG_MODE) {
    Serial.println("Web Server...Initialized");
  }
  
  AndroidServer.begin();
  if(DEBUG_MODE) {
    Serial.println("Android Server...Initialized");
  }
  
  //Initialize the X10 Output
  X10.init( 2, 3, 1 );
  Serial.println("X10 Interface...Initialized");
}

void loop()
{
  // listen for incoming clients
  Client client = AndroidServer.available();
  AndroidClient = true;
  if (!client) {
    client = BrowserServer.available();    
    AndroidClient = false;
  }
  if (client) {
    // an http request ends with a blank line
    boolean currentLineIsBlank = true;
    boolean X10CmdFound = true;
    int cInt = -1;
    int CharCount = 0;
    int FirstSpacePos = -1;
    int SecondSpacePos = -1;
    int HouseCodeVal = -1;
    int UnitCodeVal = -1;
    int ClientDigitalVal = -1;
    int DigitalVal = -1;
    
    while (client.connected()) {
      if (client.available()) {
        char c = client.read();
        if(DEBUG_MODE) {
          Serial.print(c);
        }
        CharCount++;
        // if you've gotten to the end of the line (received a newline
        // character) and the line is blank, the http request has ended,
        // so you can send a reply
        if (c == '\n' && currentLineIsBlank) {
          // send a standard http response header
          client.println("HTTP/1.1 200 OK");
          client.println("Content-Type: text/html");
          client.println();
          if(AndroidClient) {
            if(X10CmdFound) {
              client.println("SUCCESS");
            }
            else {
              client.println("EPIC FAIL");
            }
          }
          else {
            client.println("<CENTER><H2>WELCOME TO D0NN0\'S ARDUINO=>X10 WEB SERVER</H2>");
      
            if(X10CmdFound && CLIENT_DEBUG) {      
              client.println("<U>X10 REQUEST BREAKDOWN</U><br />");
              client.print("HouseCode = ");
              
              if (HouseCodeVal == ALL_ROOMS) {
                client.println("<ALL_ROOMS>");
              }
              else {
                client.println(HouseCodeEnums[HouseCodeVal]);
              }
              client.println("<br />");
              client.print("UnitCode = ");
              if (UnitCodeVal == ALL_UNITS) {
                client.println("<ALL_UNITS>");
              }
              else {
                client.println(UnitCodeEnums[UnitCodeVal]);
              }              
              client.println("<br />");
              client.print("Client Digital Val = ");
              client.println(ClientDigitalVal);
              client.println("<br />");
              client.println("---------------------<br />");
              client.print("X10.sendCmd(");
              client.print(HouseCodeEnums[HouseCodeVal]);
              client.print(",");
              client.print(UnitCodeEnums[UnitCodeVal]);
              client.print(",");
              client.print(CommandCodeEnums[DigitalVal]);
              client.println(")");
            }
            else if(!X10CmdFound) {
              client.println("<H3>EPIC FAIL</H3>");
            }
  
            client.println("</CENTER>");
          }
          break;
        }
        if (c == '\n') {
          // you're starting a new line
          currentLineIsBlank = true;
        } 
        else if (c == ' ') {
          if (FirstSpacePos > -1) {
            SecondSpacePos = CharCount;
          }
          else {
            FirstSpacePos = CharCount;
          }
          
        }
        else if (c != '\r') {
          // you've gotten a character on the current line
          currentLineIsBlank = false;
          if(X10CmdFound) {
            if((FirstSpacePos > -1) && (SecondSpacePos == -1)) {
              switch (CharCount - FirstSpacePos - 1) {
                case 1: //COMMAND CHARACTER
                  if (c != COMMAND_CHARACTER) {
                    X10CmdFound = false;
                  }
                  break;
                case 2: //HOUSE` CODE
                  //Convert Value to Integer House Code
                  cInt = int(c);
                  if(cInt != ALL_ROOMS) {
                    HouseCodeVal = cInt - A; //Constant value for 'A'
                    //Check for Invalid House Code
                    if((HouseCodeVal < 0) || (HouseCodeVal > 15)) {
                      X10CmdFound = false;
                    }
                  }
                  else {
                    HouseCodeVal = ALL_ROOMS;
                  }
                  break;
                case 3: //Unit CODE
                  cInt = int(c);
                  if (cInt != ALL_UNITS) {
                    if (cInt < A) { //Constant value for 'A'
                      cInt -= ZERO; //Constant value for '0'
                    }
                    else {
                      cInt = cInt - A + 10; //Constant value for 'A'
                    }
                  
                    if((cInt < 0) || (cInt > 16)) {
                      X10CmdFound = false;
                    }
                    else {
                      UnitCodeVal = cInt + 1; //Adjust for Hex => 1-16 as Integers
                    }
                  }
                  else {
                    UnitCodeVal = ALL_UNITS;
                  }
                  break;
                case 4: //DIGITAL COMMAND
                  ClientDigitalVal = int(c) - ZERO; //Constant ASCII value for '0'
                  if(ClientDigitalVal == 0) {
                    DigitalVal = 1;
                  }
                  else if (ClientDigitalVal == 1) {
                    DigitalVal = 0;
                  }
                  else {
                    X10CmdFound = false;
                  }
                  break;
              }
            }
          }
        }
      }
    }
    
    // give the web browser time to receive the data
    delay(1);
    // close the connection:
    client.stop();
    
    if(DEBUG_MODE) {
      Serial.print("HouseCode = ");
      if (HouseCodeVal == ALL_ROOMS) {
        Serial.println("<ALL_ROOMS>");
      }
      else if(HouseCodeVal >= 0 && HouseCodeVal <= 15) {
        Serial.println(HouseCodeEnums[HouseCodeVal]);
      }
      else {
        Serial.println("<UNKNOWN>");
      }
      Serial.print("UnitCode = ");
      if (UnitCodeVal == ALL_UNITS) {
        Serial.println("<ALL_UNITS>");
      }
      else if(UnitCodeVal >= 1 && UnitCodeVal <= 16)  {
        Serial.println(UnitCodeEnums[UnitCodeVal]);
      }
      else {
        Serial.println("<UNKNOWN>");
      }
      Serial.print("Client Digital Val = ");
      Serial.println(ClientDigitalVal);
    }
    
    if (X10CmdFound) {
      
      //Issue the appropriate X10 Commands
      if (HouseCodeVal == ALL_ROOMS) { //Also implies all devices
        for (int HouseCounter = 0; HouseCounter < 16; HouseCounter++) {
          for (int UnitCounter = 1; UnitCounter <= 16; UnitCounter++) {
            X10.sendCmd(HouseCodeEnums[HouseCounter], UnitCodeEnums[UnitCounter], CommandCodeEnums[DigitalVal]);
          }
        }
      }
      else if (UnitCodeVal == ALL_UNITS) {        
        for (int UnitCounter = 1; UnitCounter <= 16; UnitCounter++) {
          X10.sendCmd(HouseCodeEnums[HouseCodeVal], UnitCodeEnums[UnitCounter], CommandCodeEnums[DigitalVal]);
        }
      }
      else {
        X10.sendCmd(HouseCodeEnums[HouseCodeVal], UnitCodeEnums[UnitCodeVal], CommandCodeEnums[DigitalVal]);
      }
    }
    else if(DEBUG_MODE) {
      Serial.println("INVALID COMMAND");
    }
  }
}
