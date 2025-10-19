import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";


contract GovToken is ERC20Votes {
    address public shareStaker;

    constructor(address _shareStaker)
        ERC20("Governor Token", "GVNTK")
        ERC20Permit("Governor Token") // Necesario para ERC20Votes
    {
        shareStaker = _shareStaker;
    }

    function mint(address _user, uint256 _amount) external {
        require(msg.sender == shareStaker, "Not authorized");
        _mint(_user, _amount);
    }

    // ✅ Overrides requeridos
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._burn(account, amount);
    }
}
