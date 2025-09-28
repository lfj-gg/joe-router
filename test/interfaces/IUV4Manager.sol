// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IUV4Manager {
    struct ModifyLiquidityParams {
        int24 tickLower;
        int24 tickUpper;
        int256 liquidityDelta;
        bytes32 salt;
    }

    struct SwapParams {
        bool zeroForOne;
        int256 amountSpecified;
        uint160 sqrtPriceLimitX96;
    }

    struct PoolKey {
        address currency0;
        address currency1;
        uint24 fee;
        int24 tickSpacing;
        address hooks;
    }

    error AlreadyUnlocked();
    error CurrenciesOutOfOrderOrEqual(address currency0, address currency1);
    error CurrencyNotSettled();
    error DelegateCallNotAllowed();
    error InvalidCaller();
    error ManagerLocked();
    error MustClearExactPositiveDelta();
    error NonzeroNativeValue();
    error PoolNotInitialized();
    error ProtocolFeeCurrencySynced();
    error ProtocolFeeTooLarge(uint24 fee);
    error SwapAmountCannotBeZero();
    error TickSpacingTooLarge(int24 tickSpacing);
    error TickSpacingTooSmall(int24 tickSpacing);
    error UnauthorizedDynamicLPFeeUpdate();

    event Approval(address indexed owner, address indexed spender, uint256 indexed id, uint256 amount);
    event Donate(bytes32 indexed id, address indexed sender, uint256 amount0, uint256 amount1);
    event Initialize(
        bytes32 indexed id,
        address indexed currency0,
        address indexed currency1,
        uint24 fee,
        int24 tickSpacing,
        address hooks,
        uint160 sqrtPriceX96,
        int24 tick
    );
    event ModifyLiquidity(
        bytes32 indexed id,
        address indexed sender,
        int24 tickLower,
        int24 tickUpper,
        int256 liquidityDelta,
        bytes32 salt
    );
    event OperatorSet(address indexed owner, address indexed operator, bool approved);
    event OwnershipTransferred(address indexed user, address indexed newOwner);
    event ProtocolFeeControllerUpdated(address indexed protocolFeeController);
    event ProtocolFeeUpdated(bytes32 indexed id, uint24 protocolFee);
    event Swap(
        bytes32 indexed id,
        address indexed sender,
        int128 amount0,
        int128 amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick,
        uint24 fee
    );
    event Transfer(address caller, address indexed from, address indexed to, uint256 indexed id, uint256 amount);

    function allowance(address owner, address spender, uint256 id) external view returns (uint256 amount);
    function approve(address spender, uint256 id, uint256 amount) external returns (bool);
    function balanceOf(address owner, uint256 id) external view returns (uint256 balance);
    function burn(address from, uint256 id, uint256 amount) external;
    function clear(address currency, uint256 amount) external;
    function collectProtocolFees(address recipient, address currency, uint256 amount)
        external
        returns (uint256 amountCollected);
    function donate(PoolKey memory key, uint256 amount0, uint256 amount1, bytes memory hookData)
        external
        returns (int256 delta);
    function extsload(bytes32 slot) external view returns (bytes32);
    function extsload(bytes32 startSlot, uint256 nSlots) external view returns (bytes32[] memory);
    function extsload(bytes32[] memory slots) external view returns (bytes32[] memory);
    function exttload(bytes32[] memory slots) external view returns (bytes32[] memory);
    function exttload(bytes32 slot) external view returns (bytes32);
    function initialize(PoolKey memory key, uint160 sqrtPriceX96) external returns (int24 tick);
    function isOperator(address owner, address operator) external view returns (bool isOperator);
    function mint(address to, uint256 id, uint256 amount) external;
    function modifyLiquidity(PoolKey memory key, ModifyLiquidityParams memory params, bytes memory hookData)
        external
        returns (int256 callerDelta, int256 feesAccrued);
    function owner() external view returns (address);
    function protocolFeeController() external view returns (address);
    function protocolFeesAccrued(address currency) external view returns (uint256 amount);
    function setOperator(address operator, bool approved) external returns (bool);
    function setProtocolFee(PoolKey memory key, uint24 newProtocolFee) external;
    function setProtocolFeeController(address controller) external;
    function settle() external payable returns (uint256);
    function settleFor(address recipient) external payable returns (uint256);
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function swap(PoolKey memory key, SwapParams memory params, bytes memory hookData)
        external
        returns (int256 swapDelta);
    function sync(address currency) external;
    function take(address currency, address to, uint256 amount) external;
    function transfer(address receiver, uint256 id, uint256 amount) external returns (bool);
    function transferFrom(address sender, address receiver, uint256 id, uint256 amount) external returns (bool);
    function transferOwnership(address newOwner) external;
    function unlock(bytes memory data) external returns (bytes memory result);
    function updateDynamicLPFee(PoolKey memory key, uint24 newDynamicLPFee) external;
}
