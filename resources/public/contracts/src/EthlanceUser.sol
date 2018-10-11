pragma solidity ^0.4.24;

import "proxy/MutableForwarder.sol";
import "./EthlanceRegistry.sol";

/// @title User Contract
contract EthlanceUser {
    uint public constant version = 1;
    EthlanceRegistry public constant registry = EthlanceRegistry(0xdaBBdABbDABbDabbDaBbDabbDaBbdaBbdaBbDAbB);

    struct Candidate {
	bool is_registered;
	uint64 hourly_rate; // In units of currency
	uint16 currency_type; // 0: Ethereum, 1: USD, ...
	// Additional Data in Metahash
    }

    struct Employer {
	bool is_registered;
	// Additional Data in Metahash
    }

    struct Arbiter {
	bool is_registered;
	uint payment_value; // Based on type_of_payment:
	                    // [0] In units of currency
                            // [1] 1-100 for percentage
	uint16 currency_type; // 0: Ethereum, 1: USD, ...
	uint8 type_of_payment; // 0: Flat Rate, 1: Percentage
	// Additonal Data in Metahash
    }

    address public user_address;
    uint public date_created;
    uint public date_updated;
    string public metahash_ipfs;
    
    Candidate candidate_data;
    Employer employer_data;
    Arbiter arbiter_data;

    function construct(address _address, string _metahash)
	external {
	// TODO: ensure only the userfactory constructs this
	user_address = _address;
	date_created = now;
	date_updated = now;
	metahash_ipfs = _metahash;
    }


    /// @dev Fire events specific to the User
    /// @param event_name Unique to give the fired event
    /// @param event_data Additional event data to include in the
    /// fired event.
    function fireEvent(string event_name, uint[] event_data) private {
	registry.fireEvent(event_name, version, event_data);
    }


    function updateMetahash(string _metahash)
	public
        isOwner {
	updateDateUpdated();
	metahash_ipfs = _metahash;
    }


    function updateDateUpdated() internal {
	date_updated = now;
    }


    /// @dev Register Candidate for the User.
    /// @dev Note: Requires that the address is a registered user.
    /// @param hourly_rate Based on currency, the hourly suggested
    /// amount for payment.
    /// @param currency_type The type of currency to be paid in.
    function registerCandidate(uint64 hourly_rate, uint16 currency_type)
	public 
        isOwner {
	candidate_data.is_registered = true;
	candidate_data.hourly_rate = hourly_rate;
	candidate_data.currency_type = currency_type;
	updateDateUpdated();
    }


    /// @dev Update Candidate's rate of hourly pay and currency type.
    /// @param hourly_rate The rate of hourly pay for a particular currency.
    ///                    For USD, a unit of pay is a cent. For
    ///                    Ethereum, the unit of pay is a wei.
    /// @param currency_type Type of hourly pay. 0 - Eth, 1 - USD.
    function updateCandidateRate(uint64 hourly_rate,
				 uint16 currency_type)
	public
        isOwner {
	candidate_data.hourly_rate = hourly_rate;
	candidate_data.currency_type = currency_type;
	updateDateUpdated();
    }


    /// @dev Registers an Arbiter for the User.
    /// @param payment_value Unit of payment based on currency_type
    /// and type_of_payment
    /// @param currency_type Type of currency for the payment value
    ///        0 - ETH, 1 - USD
    /// @param type_of_payment Type of payment that the arbiter takes.
    ///        0 - Flat Rate, 1 - Percentage
    function registerArbiter(uint payment_value,
			     uint16 currency_type,
			     uint8 type_of_payment)
	public
        isOwner {
	arbiter_data.is_registered = true;
	arbiter_data.payment_value = payment_value;
	arbiter_data.currency_type = currency_type;
	arbiter_data.type_of_payment = type_of_payment;
	updateDateUpdated();
    }


    /// @dev Updates the given arbiter's rate of payment.
    /// @param payment_value unit of payment based on currency_type
    /// and type_of_payment
    /// @param currency_type Type of currency for the payment value
    ///        0 - ETH, 1 - USD
    /// @param type_of_payment Type of payment that the arbiter takes.
    ///        0 - Flat Rate, 1 - Percentage
    function updateArbiterRate(uint payment_value,
			       uint16 currency_type,
			       uint8 type_of_payment)
	public
        isOwner {
	arbiter_data.payment_value = payment_value;
	arbiter_data.currency_type = currency_type;
	arbiter_data.type_of_payment = type_of_payment;
	updateDateUpdated();
    }

    
    /// @dev Registers an Employee for the User.
    function registerEmployee()
	public
	isOwner {
	employer_data.is_registered = true;
	updateDateUpdated();
    }
    
    
    //
    // Modifiers
    //
    
    /// @dev Checks if the msg.sender is the owner of the user contract.
    modifier isOwner {
	require(user_address == msg.sender,
		"Unauthorized: Given user does not own this user contract.");
	_;
    }
    

}
