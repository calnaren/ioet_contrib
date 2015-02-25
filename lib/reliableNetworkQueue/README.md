Reliable Network Queue
======================
The Reliable Network Queue (RNQ) provides greater reliability than the standard network utilities provided by storm. Built on top of UDP, the Reliable Network Queue consists of a Client that repeatedly sends messages until it receives an ackowledgement from the server, and a Server that sends acknowledgements to messages received, making sure not to take action based on the received message more than once. The Network Queue Client (NQC) and Network Queue Server (NQS) abstract away these client and server behaviors, allowing one to be able to send a message from one device to another with high confidence that the message will be received. In some sense, the RNQ allows one to compromise on speed (increase the latency of communication over a network) in order to increase reliability.

In addition to repeatedly sending message, the NQC guarantees that messages will be received in the same order that they are sent. As the user requests the NQC to send messages, it buffers messages in a queue instead of sending them immediately in order to ensure that only one message is being processed at a time.

The API for using the RNQ can be found as comments in the source code.

