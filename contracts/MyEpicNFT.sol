// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

// We first import some OpenZeppelin Contracts.
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "hardhat/console.sol";

import { Base64 } from "./libraries/Base64.sol";

contract MyEpicNFT is ERC721URIStorage {
  using Counters for Counters.Counter;
  Counters.Counter private _tokenIds;

  string constant SVG_OPENING_STRING = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 800 800'><defs><filter id='a' x='-100%' y='-100%' width='400%' height='400%' filterUnits='objectBoundingBox' primitiveUnits='userSpaceOnUse' color-interpolation-filters='sRGB'><feDropShadow stdDeviation='10' dx='10' dy='10' flood-color='#000' flood-opacity='.2' x='0%' y='0%' width='100%' height='100%' result='dropShadow'/></filter><filter id='b' x='-100%' y='-100%' width='400%' height='400%' filterUnits='objectBoundingBox' primitiveUnits='userSpaceOnUse' color-interpolation-filters='sRGB'><feDropShadow stdDeviation='10' dx='10' dy='10' flood-color='#000' flood-opacity='.2' x='0%' y='0%' width='100%' height='100%' result='dropShadow'/></filter></defs><g stroke-linecap='round'>";
  string constant SVG_CLOSING_STRING = "</g></svg>";

  // -- Actual strings that we'll need to modify to add some randomness --
  // Full example of background shape: <circle r='400' cx='400' cy='400' fill='#ffb3cb'/>
  // We just need to throw in a color between these.
  string constant BACKGROUND_SHAPE_START = "<circle r='400' cx='400' cy='400' fill='";
  string constant BACKGROUND_SHAPE_END = "'/>";

  // Left eye constraints: 150 <= cx <= 290, 250 <= cy <= 300, 25 <= r <= 100
  // Right eye constraints: 510 <= cx <= 650, 250 <= cy <= 300, 25 <= r <= 100
  // Full example: <circle cx='300' cy='330' fill='#89cff0' filter='url(#a)' r='50'/>
  uint256 constant DIFF_EYE_CHANCE = 100;
  uint256 constant EYE_X_RANGE = 140;
  uint256 constant LEFT_EYE_X_START = 150;
  uint256 constant RIGHT_EYE_X_START = 510;
  uint256 constant EYE_Y_RANGE = 50;
  uint256 constant EYE_Y_START = 250;
  uint256 constant EYE_R_RANGE = 75;
  uint256 constant EYE_R_START = 25;
  string constant EYE_SHAPE_FIRST = "<circle cx='";
  string constant EYE_SHAPE_SECOND = "' cy='";
  string constant EYE_SHAPE_THIRD = "' fill='";
  string constant EYE_SHAPE_FOURTH = "' filter='url(#a)' r='";
  string constant EYE_SHAPE_FIFTH = "'/>";

  // smiley -- m100 500 q0-600 75-350 600 0 stroke-width=5-25
  // frowney -- m100 600 q0-600 -350--75 600 0 stroke-width=5-25
  // full example -- <path d='m250 450 q180 300 300 0' stroke-width='10' stroke='#7c0a02' fill='none' filter='url(#b)'/>
  uint256 constant MOUTH_FROWN_CHANCE = 10;
  uint256 constant MOUTH_QX_VAL_RANGE = 600;
  uint256 constant MOUTH_QX_VAL_START = 0;
  uint256 constant MOUTH_QY_VAL_RANGE = 275;
  uint256 constant MOUTH_QY_VAL_START = 75;
  uint256 constant MOUTH_WIDTH_RANGE = 20;
  uint256 constant MOUTH_WIDTH_START = 5;
  string constant MOUTH_SHAPE_FIRST_SMILE = "<path d='m100 500 q";
  string constant MOUTH_SHAPE_FIRST_FROWN = "<path d='m100 600 q";
  string constant MOUTH_SHAPE_SECOND_SMILE = " ";
  string constant MOUTH_SHAPE_SECOND_FROWN = " -";
  string constant MOUTH_SHAPE_THIRD = " 600 0' stroke-width='";
  string constant MOUTH_SHAPE_FOURTH = "' stroke='";
  string constant MOUTH_SHAPE_FIFTH = "' fill='none' filter='url(#b)'/>";

  // Use a different set of colors for face and features
  // This provides more variety, but mostly ensures we don't have features that blend in 
  string[] featureColors = ["#a5821a", "#48f2f9", "#7b83f0", "#377453", "#141263", "#21b059", "#54cdb2", "#71ff47", "#bdf0d2", "#73df50", "#68a0f6"];
  string[] faceColors = ["#c8920f", "#b38a98", "#1379e5", "#ffc4a8", "#cd96d9", "#691fbe", "#4859d5", "#2486a3", "#ef84c5", "#e47057"];

  // We need to pass the name of our NFTs token and its symbol.
  constructor() ERC721 ("SmileyNFT", "SMILES") {
    console.log("This is my awesome smiley (maybe frowny) face NFT collection!");
  }

  function random(string memory input) internal pure returns (uint256) {
    return uint256(keccak256(abi.encodePacked(input)));
  }

  function pickRandomFaceColor(uint256 tokenId) public view returns (string memory) {
    // "seed" the generator
    uint256 rand = random(string(abi.encodePacked("a face color", Strings.toString(tokenId))));
    // Squash the # between 0 and the length of the array to avoid going out of bounds.
    rand = rand % faceColors.length;
    return string(abi.encodePacked(BACKGROUND_SHAPE_START, faceColors[rand], BACKGROUND_SHAPE_END));
  }

  function generateRandomEyes(uint256 tokenId) public view returns (string memory) {
    // Determine the our first eye color. Later we'll roll to see if we should have a different second eye
    uint256 eyeColorRand = random(string(abi.encodePacked("first eye color", Strings.toString(tokenId))));
    eyeColorRand = eyeColorRand % featureColors.length;
    string memory firstEyeColor = featureColors[eyeColorRand];

    // Now let's determine if we should have different eye colors. This will
    // actually be fairly rare, let's do a 1 out of 100 chance
    string memory secondEyeColor;
    uint256 sameEyeRand = random(string(abi.encodePacked("different eyes", Strings.toString(tokenId))));
    sameEyeRand = sameEyeRand % DIFF_EYE_CHANCE;
    if (sameEyeRand == 0) {
      eyeColorRand = random(string(abi.encodePacked("second eye color", Strings.toString(tokenId))));
      // Technically this could result in the same color as before. I guess that's just bad luck and
      // makes two different eye colors slightly rarer.
      eyeColorRand = eyeColorRand % featureColors.length;
      secondEyeColor = featureColors[eyeColorRand];
    } else {
      secondEyeColor = firstEyeColor;
    }
  
    // "seed" the generator, use these for left eye values
    uint256 leftEyeXRand = random(string(abi.encodePacked("a left eye x pos", Strings.toString(tokenId))));
    leftEyeXRand = (leftEyeXRand % EYE_X_RANGE) + LEFT_EYE_X_START;

    uint256 leftEyeYRand = random(string(abi.encodePacked("a left eye y pos", Strings.toString(tokenId))));
    leftEyeYRand = (leftEyeYRand % EYE_Y_RANGE) + EYE_Y_START;
    
    uint256 leftEyeRRand = random(string(abi.encodePacked("a left eye r val", Strings.toString(tokenId))));
    leftEyeRRand = (leftEyeRRand % EYE_R_RANGE) + EYE_R_START;

    // use these for right eye values
    uint256 rightEyeXRand = random(string(abi.encodePacked("a right eye x pos", Strings.toString(tokenId))));
    rightEyeXRand = (rightEyeXRand % EYE_X_RANGE) + RIGHT_EYE_X_START;

    uint256 rightEyeYRand = random(string(abi.encodePacked("a right eye y pos", Strings.toString(tokenId))));
    rightEyeYRand = (rightEyeYRand % EYE_Y_RANGE) + EYE_Y_START;

    uint256 rightEyeRRand = random(string(abi.encodePacked("a right eye r val", Strings.toString(tokenId))));
    rightEyeRRand = (rightEyeRRand % EYE_R_RANGE) + EYE_R_START;

    // First x, then y, then color, then r 
    string memory leftEyeString = string(abi.encodePacked(EYE_SHAPE_FIRST, Strings.toString(leftEyeXRand),
                                                          EYE_SHAPE_SECOND, Strings.toString(leftEyeYRand),
                                                          EYE_SHAPE_THIRD, firstEyeColor,
                                                          EYE_SHAPE_FOURTH, Strings.toString(leftEyeRRand),
                                                          EYE_SHAPE_FIFTH));

    string memory rightEyeString = string(abi.encodePacked(EYE_SHAPE_FIRST, Strings.toString(rightEyeXRand),
                                                           EYE_SHAPE_SECOND, Strings.toString(rightEyeYRand),
                                                           EYE_SHAPE_THIRD, secondEyeColor,
                                                           EYE_SHAPE_FOURTH, Strings.toString(rightEyeRRand),
                                                           EYE_SHAPE_FIFTH));

    // console.log("Generated left eye string: %s", leftEyeString);
    // console.log("Generated right eye string: %s", rightEyeString);
    return string(abi.encodePacked(leftEyeString, rightEyeString));
  }

  function generateRandomMouth(uint256 tokenId) public view returns (string memory) {
    // Determine the mouth color.
    uint256 mouthColorRand = random(string(abi.encodePacked("mouth color", Strings.toString(tokenId))));
    mouthColorRand = mouthColorRand % featureColors.length;
    string memory mouthColor = featureColors[mouthColorRand];

    // Now let's determine if we should have a frowny face. This will
    // actually be fairly rare, let's do a 1 out of 10 chance
    bool frowny = false;
    uint256 frownyRand = random(string(abi.encodePacked("frowny face", Strings.toString(tokenId))));
    frownyRand = frownyRand % DIFF_EYE_CHANCE;
    if (frownyRand == 0) {
      frowny = true;
    }
  
    // "seed" the generator
    uint256 mouthQXRand = random(string(abi.encodePacked("a mouth qx value", Strings.toString(tokenId))));
    mouthQXRand = (mouthQXRand % MOUTH_QX_VAL_RANGE) + MOUTH_QX_VAL_START;

    uint256 mouthQYRand = random(string(abi.encodePacked("a mouth qy value", Strings.toString(tokenId))));
    mouthQYRand = (mouthQYRand % MOUTH_QY_VAL_RANGE) + MOUTH_QY_VAL_START;
    
    uint256 mouthWidthRand = random(string(abi.encodePacked("a mouth width value", Strings.toString(tokenId))));
    mouthWidthRand = (mouthWidthRand % MOUTH_WIDTH_RANGE) + MOUTH_WIDTH_START;


    // First qx, then qy, then width, then color
    // full example -- <path d='m250 450 q180 300 300 0' stroke-width='10' stroke='#7c0a02' fill='none' filter='url(#b)'/>
    string memory mouthString;
    if (frowny) {
      mouthString = string(abi.encodePacked(MOUTH_SHAPE_FIRST_FROWN, Strings.toString(mouthQXRand),
                                            MOUTH_SHAPE_SECOND_FROWN, Strings.toString(mouthQYRand),
                                            MOUTH_SHAPE_THIRD, Strings.toString(mouthWidthRand),
                                            MOUTH_SHAPE_FOURTH, mouthColor,
                                            MOUTH_SHAPE_FIFTH));
    } else {
      mouthString = string(abi.encodePacked(MOUTH_SHAPE_FIRST_SMILE, Strings.toString(mouthQXRand),
                                            MOUTH_SHAPE_SECOND_SMILE, Strings.toString(mouthQYRand),
                                            MOUTH_SHAPE_THIRD, Strings.toString(mouthWidthRand),
                                            MOUTH_SHAPE_FOURTH, mouthColor,
                                            MOUTH_SHAPE_FIFTH));
    }

    // console.log("Generated mouth string: %s", mouthString);
    return mouthString;
  }

  function makeAnEpicNFT() public {
    uint256 newItemId = _tokenIds.current();

    // Grab our face, some eyes, and a mouth
    string memory face = pickRandomFaceColor(newItemId);
    string memory eyes = generateRandomEyes(newItemId);
    string memory mouth = generateRandomMouth(newItemId);
    // Concatenate it all together, surrounded by our opening and closing tags.
    string memory finalSvg = string(abi.encodePacked(SVG_OPENING_STRING, face, eyes, mouth, SVG_CLOSING_STRING));

    // Get all the JSON metadata in place and base64 encode it.
    string memory json = Base64.encode(
        bytes(
            string(
                abi.encodePacked(
                    '{"name": "',
                    // We set the title of our NFT as "Smiley #<itemId>".
                    string(abi.encodePacked("Smiley #", Strings.toString(newItemId))),
                    '", "description": "A collection of smiles. Maybe some frowns.", "image": "data:image/svg+xml;base64,',
                    // We add data:image/svg+xml;base64 and then append our base64 encode our svg.
                    Base64.encode(bytes(finalSvg)),
                    '"}'
                )
            )
        )
    );

    // Just like before, we prepend data:application/json;base64, to our data.
    string memory finalTokenUri = string(
        abi.encodePacked("data:application/json;base64,", json)
    );

    console.log("\n--------------------");
    console.log(finalTokenUri);
    console.log("--------------------\n");

    _safeMint(msg.sender, newItemId);
  
    _setTokenURI(newItemId, finalTokenUri);
  
    _tokenIds.increment();
    console.log("An NFT w/ ID %s has been minted to %s", newItemId, msg.sender);
  }
}