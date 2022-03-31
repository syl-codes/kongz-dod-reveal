pragma solidity ^0.5.0;

import "./IKIP7.sol";

contract Reveal {

  address private _oldContract;
  address private _newContract;

  address private _mkcContract;

  address private _admin;

  uint256[] private _waitForReveal;
  uint256 private _revealFee;
  string  private _baseURI;

  event Revealed(address addr, uint256 from, uint256 to);

  constructor (address oldContract, address newContract) public {
    _admin = msg.sender;
    _oldContract = oldContract;
    _newContract = newContract;
    _mkcContract = address(0x119883eE408AA5B9625C5D09A79fA8Be9F9f6017);
    _revealFee = 4000000000000000000;
    _baseURI = "https://mutant.by-syl.com/json/";
  }

  modifier onlyAdmin() {
    require(_admin == msg.sender, "only admin");
    _;
  }

  function totalArray() external view returns (uint256) {
    return _waitForReveal.length;
  }

  function generateArray(uint startLoop, uint endLoop) external onlyAdmin {
    for(uint256 i = startLoop; i <= endLoop; i++){
      _waitForReveal.push(i);
    }
  }

  function renounce() external onlyAdmin {
    bool success;
    bytes memory data;
    (success, data) = _newContract.call(abi.encodeWithSignature("renounceMinter()"));
  }

  function withdraw() external onlyAdmin {
    IKIP7 mkcToken = IKIP7(_mkcContract);
    uint256 totalValue = mkcToken.balanceOf(address(this));
    mkcToken.approve(address(this), totalValue);
    mkcToken.transferFrom(address(this), msg.sender, totalValue);
  }

  function reveal(uint256 nftId) public {

    //Check Balance
    IKIP7 mkcToken = IKIP7(_mkcContract);
    require(mkcToken.balanceOf(msg.sender) >= _revealFee, "lack of balance");

    //Check Bot
    require(msg.sender == tx.origin, "Not allowed (1)");

    //Check Owner
    bool success = true;
    bytes memory data = "";
    (success, data) = _oldContract.call(abi.encodeWithSignature("ownerOf(uint256)", nftId));
    require(success == true, "contract call failed (1)");
    address holder = abi.decode(data, (address));

    require(msg.sender == holder, "Not allowed (2)");

    //shuffle and get last.
    _shuffle();
    uint256 revealed = _waitForReveal[_waitForReveal.length - 1];
    _waitForReveal.pop();

    //Pay
    uint256 allowance = mkcToken.allowance(msg.sender, address(this));
    require(allowance >= _revealFee, "Check the token allowance");
    mkcToken.transferFrom(msg.sender, address(this), _revealFee);

    //Burn
    (success, data) = _oldContract.call(abi.encodeWithSignature("burn(uint256)", nftId));
    require(success == true, "contract call failed (2)");

    //Mint
    string memory metadata = string(abi.encodePacked(_baseURI, uint2str(revealed),".json"));
    (success, data) = _newContract.call(
        abi.encodeWithSignature(
          "mintWithTokenURI(address,uint256,string)", msg.sender, revealed, metadata));
    require(success == true, "contract call failed (4)");

    //Log
    emit Revealed(msg.sender, nftId, revealed);
  }

  function _shuffle() internal {
    uint256 i = _waitForReveal.length - 1;
    uint256 n = uint256(keccak256(abi.encodePacked(block.timestamp))) % (_waitForReveal.length);
    uint256 temp = _waitForReveal[n];
    _waitForReveal[n] = _waitForReveal[i];
    _waitForReveal[i] = temp;
  }

  function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
    if (_i == 0) {
      return "0";
    }
    uint j = _i;
    uint len;
    while (j != 0) {
      len++;
      j /= 10;
    }
    bytes memory bstr = new bytes(len);
    uint k = len - 1;
    while (_i != 0) {
      bstr[k--] = byte(uint8(48 + _i % 10));
      _i /= 10;
    }
    return string(bstr);
  }
}
