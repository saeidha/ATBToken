// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract PublicChat is Ownable {
    struct Message {
        address sender;
        string text;
        uint256 timestamp;
        uint256 likes;
    }

    Message[] public messages;

    event NewMessage(address indexed sender, string text, uint256 timestamp);
    event Gm(address indexed sender, uint256 timestamp);

    constructor() Ownable(msg.sender) {}

    function sendMessage(string calldata _text) external {
        messages.push(Message({
            sender: msg.sender,
            text: _text,
            timestamp: block.timestamp,
            likes: 0
        }));

        emit NewMessage(msg.sender, _text, block.timestamp);
    }

    function send() external {
        emit Gm(msg.sender, block.timestamp);
    }

    function likeMessage(uint256 _messageIndex) external {
        require(_messageIndex < messages.length, "Message does not exist");
        messages[_messageIndex].likes++;
    }

    function getMessages() external view returns (Message[] memory) {
        return messages;
    }
}
