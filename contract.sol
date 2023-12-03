pragma solidity 0.6.0;
pragma experimental ABIEncoderV2;

interface IERC20 {
    function balanceOf(address account) external view returns (uint);
    function transfer(address recipient, uint amount) external returns (bool);
}
interface PriceInfo {
    function latestAnswer() external view returns (uint256);
}

contract TronGoogol {
    using SafeMath for uint256;
    uint256 constant public TOTAL_REF = 50;
    uint256 constant public CEO_FEE = 50;
    uint256 constant public PERCENTS_DIVIDER = 1000;
    uint256 public totalInvested=0;
    uint256 public usercount=1;
    uint8 public treecount=0;
    struct Plan {
        uint256 board;
        uint256 amount;
    }
    Plan[] internal plans;
    struct Tree {
        uint8 treeid;
        uint8 boardid;
        uint256 position;
        uint256 amount;
        address parent;
        address referrer;
    }
    struct User {
        Tree[] trees;
        uint256 deposited;
        uint256 received;
        uint256 referralamount;
        uint256 referralscount;
    }

    mapping (address => User) internal users;
    mapping (uint => mapping (uint => uint256)) internal usertreecount;
    mapping (uint => mapping (uint => mapping (uint => address))) internal usersposition;
    mapping (uint => mapping (uint => mapping (address => mapping (uint => address)))) internal usertreeposition;
    mapping (uint => mapping (uint => mapping (address => address))) internal userparents;
    mapping (uint => mapping (uint => mapping (address => uint256))) internal userearnings;
    mapping (uint => mapping (uint => mapping (address => uint256))) internal userreferrals;
    mapping (uint => mapping (uint => mapping (address => uint256))) internal userpayments;
    mapping (uint => mapping (uint => mapping (address => bool))) public rejoiningusage;
    
    uint256 secondlevelrefcondition=2;
    uint256 thirdlevelrefcondirion=5;
    address payable public ceoWallet;
    address payable public admin1=0x896D392f52A43b987Db0169897302578881F8C6d; //dev 1 
    address payable public admin2=0x9bfCD348B1D298072e68F3550B204092c0e985a9; //planet 1 
    address payable public admin3=0x164E42cD99B651c464Daff1D23Ec3C4FB68A2b5e; //planet 2 

    address payable public charity1=0xa6B0a36D7c77f4e99484DAc6dBb8960a119eA087; //charity dev
    address payable public charity2=0x85C30DF6D5d14475850447A0F11C237Dda435FFF; //planet 1 charity
    address payable public charity3=0x34a6D4223396F6679192a17dF37F66705Bd9D12A; //planet 2 charity
    address payable public charity4=0x61f2157469C8842EfA7d511Cd890dC9e89D90dF8; //planet 3 charity

    event Newbie(address user);
    event NewDeposit(address indexed user, uint8 tree, uint8 board, uint256 amount, uint256 time, address referrer,uint256 position,address parent,uint8 side);
    event RefBonus(address indexed referrer, address indexed referral, uint8 tree, uint8 board,uint256 amount,uint256 timestamp);
    event FeePayed(address indexed user, uint256 totalAmount);

    constructor() public {
        ceoWallet = msg.sender;
        plans.push(Plan(0,25));
        plans.push(Plan(1,50));
        plans.push(Plan(2,100));
        CreateTree();
    }
    function Register(address referrer, uint8 tree,uint8 board) public  payable {
        RegisterInternal(msg.sender,referrer,tree,board);
    }
    function RegisterRejoin(address referrer, uint8 tree,uint8 board) public  payable {
        require(iseligibleforreentry(msg.sender,tree,board), "not eligible for rejoin");
        require(rejoiningusage[tree][board][msg.sender]==false, "rejoining done");
        uint8 nexttree= getnextavailabletree(msg.sender,board);
        require(nexttree <= treecount , "No Tree availailable for rejoining");
        require((getpostionintree(msg.sender,nexttree,board)==0) , "User registered already");
        RegisterInternal(msg.sender,referrer,nexttree,board);
        rejoiningusage[tree][board][msg.sender]=true;
        userreferrals[nexttree][board][msg.sender]= userreferrals[tree][board][msg.sender];
    
    }
    function RegisterAdmin(address useraddress,address referrer, uint8 tree,uint8 board) public  payable {
        require(msg.sender == ceoWallet, "only owner");
        if(useraddress != address(0))
        {
            RegisterInternal(useraddress,referrer,tree,board);
        }
        else 
        {
            RegisterInternal(address(usertreecount[tree][board]),ceoWallet,tree,board);
        }
    }
    function RegisterInternal(address useraddress,address referrer, uint8 tree,uint8 board) internal {
        require(board < 3, "Invalid Board");
        require(tree <= treecount, "Invalid Tree");
        require((getpostionintree(useraddress,tree,board)==0), "User registered already");
        require(validateprevioustree(useraddress,tree,board), "Complete previous board to use this board");
        require(((((plans[board].amount -1)*(10**8))/(PriceInfo(0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE).latestAnswer())) < msg.value) || (msg.sender == ceoWallet) ,"Amount less than required");
        
        User storage user = users[useraddress];
        address _referrer;
        if((getpostionintree(referrer,tree,board) >0) && (referrer != useraddress)) {
            _referrer = referrer;
        }
        else
        {
            _referrer = ceoWallet;
        }
        users[_referrer].referralscount = users[_referrer].referralscount +1;
        userreferrals[tree][board][_referrer]=userreferrals[tree][board][_referrer]+1;
        usertreecount[tree][board]= usertreecount[tree][board]+1;
        if (user.trees.length == 0) {
            emit Newbie(useraddress);
            usercount=usercount+1;
        }
        totalInvested = totalInvested.add(msg.value);
        (address parent, uint8 side) = getparent(tree, board, _referrer);
        user.trees.push(Tree(tree, board, usertreecount[tree][board],msg.value,parent,_referrer));
        usertreeposition[tree][board][parent][side]= useraddress;
        userparents[tree][board][useraddress]=parent;
        emit NewDeposit(useraddress, tree, board, msg.value, block.timestamp,_referrer,usertreecount[tree][board],parent,side);
        address receiver=getReceiver(tree,board,useraddress);
        if(receiver ==address(0))
        {
            distributeCharity(msg.value.mul(90).div(100));
        }
        else 
        {
            payable(receiver).transfer(msg.value.mul(90).div(100));
            users[receiver].received= users[receiver].received+msg.value.mul(90).div(100);
            userearnings[tree][board][receiver]= userearnings[tree][board][receiver]+msg.value.mul(90).div(100);
            userpayments[tree][board][receiver]= userpayments[tree][board][receiver]+1;
        }
        distributeadminfee(_referrer,tree,board,msg.value.div(10));
        usersposition[tree][board][usercount]= useraddress;
    }
    function getparent(uint8 tree, uint8 board, address add) public view returns(address , uint8)
    {
        if(gettreepositions(tree, board,add,0) == address(0))
            return (add,0);
        if(gettreepositions(tree, board,add,1) == address(0))
            return (add,1);    
        if( getcount(tree, board,gettreepositions(tree, board,add,0)) > getcount(tree, board,gettreepositions(tree, board,add,1)) )
            return  ( getparent(tree,board,gettreepositions(tree, board,add,1)));
        else 
            return ( getparent(tree,board,gettreepositions(tree, board,add,0)));
    }
    function getchildcountatlevel( address add,uint8 tree, uint8 board,uint8 level) public view returns(  uint256)
    {
        if(add == address(0))
            return 0;
        else if((add != address(0)) && (level ==0))
            return 1;
        else if((add != address(0)) && (level > 0))
            return  (
                getchildcountatlevel(usertreeposition[tree][board][add][0],tree,board, level-1)+
                getchildcountatlevel(usertreeposition[tree][board][add][1],tree,board, level-1));
        else 
            return 0;
    }
    function getnextavailabletree(address useraddress,uint8 board) public view returns (uint8)
    {
        for (uint8 i = 1; i <= treecount; i++) {
            if(getpostionintree(useraddress, i, board) ==0)
                return i;
        }
        return treecount+1;
    }
    function getReceiver(uint8 tree, uint8 board,address add) public view returns (address)
    {
            address addr= userparents[tree][board][userparents[tree][board][userparents[tree][board][add]]];
            uint256 childcount=getchildcountatlevel(addr,tree,board,3);
            if(childcount <=3)
            {
                return addr;
            }
            else 
            {
                if(childcount <=6)
                {
                    addr =userparents[tree][board][userparents[tree][board][userparents[tree][board][addr]]];
                    if(userreferrals[tree][board][addr] <secondlevelrefcondition)
                    {
                        return  address(0);
                    }
                    else 
                        return  addr;
                }
                else 
                {
                    addr =userparents[tree][board][userparents[tree][board][userparents[tree][board][addr]]];
                    addr =userparents[tree][board][userparents[tree][board][userparents[tree][board][addr]]];
                    if(userreferrals[tree][board][addr] <thirdlevelrefcondirion)
                    {
                        return  address(0);
                    }
                    else 
                        return  addr;
                }
            }
    }
    function distributeCharity(uint256 amount) public payable 
    {
        payable(charity1).transfer(amount.mul(15).div(100));
        payable(charity2).transfer(amount.mul(60).div(100));
        payable(charity3).transfer(amount.mul(20).div(100));
        payable(charity4).transfer(amount.mul(5).div(100));
    }
    function distributeadminfee(address referrer,uint8 tree,uint8 board,uint256 amount) public payable 
    {
        if(referrer == ceoWallet)
        {
            payable(admin1).transfer(amount.mul(30).div(100));
            payable(admin2).transfer(amount.mul(60).div(100));
            payable(admin3).transfer(amount.mul(10).div(100));
        }
        else if(board == 0)
        {
            payable(admin1).transfer(amount.mul(15).div(100));
            payable(admin2).transfer(amount.mul(30).div(100));
            payable(admin3).transfer(amount.mul(5).div(100));
            payable(referrer).transfer(amount.mul(50).div(100));
            users[referrer].referralamount= users[referrer].referralamount+amount.mul(50).div(100);
            emit RefBonus(referrer, msg.sender,tree,board, amount.mul(50).div(100),block.timestamp);
        }
        else if (board == 1)
        {
            payable(admin1).transfer(amount.mul(20).div(100));
            payable(admin2).transfer(amount.mul(30).div(100));
            payable(admin3).transfer(amount.mul(10).div(100));
            payable(referrer).transfer(amount.mul(40).div(100));
            users[referrer].referralamount= users[referrer].referralamount+amount.mul(40).div(100);
            emit RefBonus(referrer, msg.sender,tree,board, amount.mul(40).div(100),block.timestamp);
        }
        else if(board == 2)
        {
            payable(admin1).transfer(amount.mul(20).div(100));
            payable(admin2).transfer(amount.mul(35).div(100));
            payable(admin3).transfer(amount.mul(15).div(100));
            payable(referrer).transfer(amount.mul(30).div(100));
            users[referrer].referralamount= users[referrer].referralamount+amount.mul(30).div(100);
            emit RefBonus(referrer, msg.sender,tree,board, amount.mul(30).div(100),block.timestamp);
        }
        else {
            payable(ceoWallet).transfer(amount);
            users[referrer].referralamount= users[referrer].referralamount+amount;
            emit RefBonus(ceoWallet, msg.sender,tree,board, amount,block.timestamp);
        }
    }
    function iseligibleforreentry(address addr,uint8 tree,uint8 board) public view returns (bool)
    {
        uint256 childcount= getchildcountatlevel(addr,tree,board,9);
        if(childcount >= 512 ) 
            return true;
        return false;
    }
    function validateprevioustree(address addr,uint8 tree, uint8 board) public view returns (bool)
    {
        if(board == 0)
            return true;
        if(getpostionintree(addr, tree, board-1) == 0)
            return false;
        if((board ==2) && (getpostionintree(addr, tree, board-2) == 0) )
            return false;    
        return true;
    }
    function getpostionintree(address addr,uint8 tree, uint8 board) public view returns (uint256)
    {
        uint256 position=0;
        for (uint256 i = 0; i < users[addr].trees.length; i++) {
            if((users[addr].trees[i].treeid== tree) && ( users[addr].trees[i].boardid == board) )
            {
                position = users[addr].trees[i].position;
            }
        }
        return position;
    }
    function getcount(uint8 tree, uint8 board,address addr) public view returns (uint256)
    {
        if(addr== address(0))
            return 1;
        return getcount(tree,board, gettreepositions(tree,board,addr,0)) + getcount(tree,board,gettreepositions(tree,board,addr,1)) ;
    }
    function getUserTotalReferrals(address userAddress) public view returns(uint256 referrals) {
        return users[userAddress].referralscount;
    }
    function gettreepositions( uint8 tree, uint8 board,address addr, uint8 side) public view returns (address)
    {
        return usertreeposition[tree][board][addr][side];
    }
    function CreateTree() public
    {
        // need to implement
        require(msg.sender == ceoWallet, "only owner");
        treecount=treecount+1;
        usersposition[treecount][0][0]= address(0);
        usersposition[treecount][1][0]= address(0);
        usersposition[treecount][2][0]= address(0);
        users[address(0)].trees.push(Tree(treecount, 0, 0,0,address(0),address(0)));
        users[address(0)].trees.push(Tree(treecount, 1, 0,0,address(0),address(0)));
        users[address(0)].trees.push(Tree(treecount, 2, 0,0,address(0),address(0)));
        usersposition[treecount][0][1]= msg.sender;
        usersposition[treecount][1][1]= msg.sender;
        usersposition[treecount][2][1]= msg.sender;
        users[msg.sender].trees.push(Tree(treecount, 0, 1,0,address(0),address(0)));
        users[msg.sender].trees.push(Tree(treecount, 1, 1,0,address(0),address(0)));
        users[msg.sender].trees.push(Tree(treecount, 2, 1,0,address(0),address(0)));
        usertreecount[treecount][0]= 1;
        usertreecount[treecount][1]= 1;
        usertreecount[treecount][2]= 1;
        emit NewDeposit(msg.sender, treecount, 0, 0, block.timestamp,address(0),1,address(0),0);
        emit NewDeposit(msg.sender, treecount, 1, 0, block.timestamp,address(0),1,address(0),0);
        emit NewDeposit(msg.sender, treecount, 2, 0, block.timestamp,address(0),1,address(0),0);
    }
    function getUserDepositInfo(address userAddress,uint256 position) public view returns(Tree memory,uint256,uint256, uint256, bool,bool) {
        address addr=userAddress;
        User storage user=users[addr];
        uint8 treeid=user.trees[position].treeid;
        uint8 boardid=user.trees[position].boardid;
        return (
            user.trees[position],
            userearnings[treeid][boardid][addr],
            userreferrals[treeid][boardid][addr],
            userpayments[treeid][boardid][addr],
            iseligibleforreentry(addr,treeid,boardid),
            rejoiningusage[treeid][boardid][addr]
            );
    }
    function getUserNumberOfDeposits(address userAddress) public view returns(uint256) {
        return users[userAddress].trees.length;
    }
    function getUserTotalDeposits(address userAddress) public view returns(uint256 amount) {
        for (uint256 i = 0; i < users[userAddress].trees.length; i++) {
            amount = amount.add(users[userAddress].trees[i].amount);
        }
    }
    function getSiteInfo() public view returns(uint256 _totalInvested, uint256 _usercount, uint8 _treecount) {
        return(totalInvested,usercount,treecount);
    }
    function getUserInfo(address userAddress) public view returns(uint256 totalDeposit, uint256 totalreceived, uint256 totalReferralamount,uint256 totalreferealusers) {
        return(getUserTotalDeposits(userAddress), users[userAddress].received, users[userAddress].referralamount,getUserTotalReferrals(userAddress));
    }
    //config
    function updatesecondlevelreferral(uint256 _secondcount, uint256 _thirdcount) public  {
        require(msg.sender == ceoWallet, "only owner");
        secondlevelrefcondition=_secondcount;
        thirdlevelrefcondirion=_thirdcount;
    }
    function withdrawTokens(address tokenAddr) external {
        IERC20 alttoken = IERC20(tokenAddr);
        alttoken.transfer(ceoWallet,alttoken.balanceOf(address(this)));
    }
    function AdminwithdrawAll() external {
        require(msg.sender == ceoWallet, "only owner");
        distributeCharity(address(this).balance);
    }
}
library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;
        return c;
    }
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        return c;
    }
    function Modulo(uint256 a, uint256 b) internal pure returns (uint)
    {
        require(b > 0, "SafeMath: division by zero");
        return a % b ;
    }
    function baseuser(uint256 a, uint256 b) internal pure returns (uint)
    {
        require(b > 0, "baseuser: division by zero");
        return sub(a,Modulo(a,b));
    }
    function power(uint256 a, uint256 b) internal pure returns (uint)
    {
        require(b >= 0, "power: -ve not allowed");
        return a ** b ;
    }
}
