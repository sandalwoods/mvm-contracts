pragma solidity =0.6.6;

import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';

import './interfaces/IUniswapV2Router02.sol';
import './interfaces/IERC20.sol';
import './libraries/UniswapV2Library.sol';
contract UniswapMVMRouter {
    address immutable router;
    uint256 constant AGE = 300;
    mapping(address => Operation) public operations;

    struct Operation {
        address asset;
        uint256 amount;
        uint256 deadline;
    }

    constructor(address _router) public {
        router = _router;
    }

    function addLiquidity(address asset, uint256 amount) public {
        IERC20(asset).transferFrom(msg.sender, address(this), amount);

        Operation memory op = operations[msg.sender];
        if (op.asset == address(0)) {
            op.asset = asset;
            op.amount = amount;
            op.deadline = block.timestamp + AGE;
            operations[msg.sender] = op;
            return;
        }

        if (op.deadline < block.timestamp || op.asset == asset) {
            IERC20(op.asset).transfer(msg.sender, op.amount);
            IERC20(asset).transfer(msg.sender, amount);
            operations[msg.sender].asset = address(0);
            return;
        }

        IERC20(op.asset).approve(router, op.amount);
        IERC20(asset).approve(router, amount);

        uint256 amountA = op.amount;
        uint256 amountB = amount;
        uint256 liquidity;
        (amountA, amountB, liquidity) = IUniswapV2Router02(router).addLiquidity(
            op.asset, asset,
            amountA, amountB,
            amountA / 2, amountB / 2,
            msg.sender,
            block.timestamp + AGE
        );

        if (op.amount > amountA) {
            IERC20(op.asset).transfer(msg.sender, op.amount - amountA);
            IERC20(op.asset).approve(router, 0);
        }
        if (amount > amountB) {
            IERC20(asset).transfer(msg.sender, amount - amountB);
            IERC20(asset).approve(router, 0);
        }
        operations[msg.sender].asset = address(0);
    }


    function removeLiquidity(
        address pair,
        address tokenA,
        address tokenB,
        address to,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin
    ) public {
        pair.call(abi.encodeWithSignature("approve(address,uint256)",router, liquidity));
        IUniswapV2Router02(router).removeLiquidity(
            tokenA, tokenB,
            liquidity,
            amountAMin, amountBMin,
            to,
            block.timestamp + AGE
        );
    }

    function claim() public {
        Operation memory op = operations[msg.sender];
        if (op.asset == address(0)) {
            return;
        }
        IERC20(op.asset).transfer(msg.sender, op.amount);
    }
}
