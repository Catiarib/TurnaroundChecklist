// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title TurnaroundChecklist
 * @dev Aircraft turnaround smart contract system
 * @notice Manages a single turnaround with 27 tasks, KPI computation, and certification
 * @author Decode Travel Barcelona 2025 Hackathon Team
 * Winner of Blockchain-based Turnaround Checklist Challenge
 * Chain4Travel · Camino Network · Vueling Airlines
 */
contract TurnaroundChecklist is AccessControl {
    // ============================================================
    // CONSTANTS & IMMUTABLES
    // ============================================================

    bytes32 public constant OPS_ROLE = keccak256("OPS_ROLE");
    uint256 private constant TASK_COUNT = 27;

    // ============================================================
    // ENUMS & STRUCTS
    // ============================================================

    enum Actor {
        GroundHandling,
        Cleaning,
        Fuel,
        Catering,
        FlightCrew,
        Gate
    }

    enum TaskStatus {
        Pending,
        OnTime,
        Late
    }

    struct Task {
        Actor assignedActor;      // Responsible actor for this task
        uint256 deadline;         // Task deadline (timestamp)
        bool isMandatory;         // Whether task is mandatory for certification
        TaskStatus status;        // Current task status
        bool isCompleted;         // Whether task is completed
        uint256 completedAt;      // Completion timestamp (0 if not completed)
        string justification;     // Optional delay justification
    }

    struct TurnaroundInfo {
        string offChainId;        // Off-chain turnaround ID (e.g., "BCN-FR123-2026-01-09")
        string airportCode;       // IATA airport code (e.g., "BCN")
        uint256 scheduledArrival; // Scheduled arrival time
        uint256 scheduledDeparture; // Scheduled departure time
        uint256 actualDeparture;  // Actual departure (0 if not certified)
        bool isCertified;         // Whether turnaround is certified
        bytes32 certificationHash; // Cryptographic hash of certification data
    }

    // ============================================================
    // STATE VARIABLES
    // ============================================================

    TurnaroundInfo public turnaroundInfo;
    Task[TASK_COUNT] public tasks;
    mapping(Actor => address) public actorWallets;
    address public badgeContract; // TurnaroundBadge NFT contract

    // ============================================================
    // EVENTS
    // ============================================================

    event TurnaroundCreated(
        string offChainId,
        string airportCode,
        uint256 scheduledArrival,
        uint256 scheduledDeparture
    );

    event TaskCompleted(
        uint256 indexed taskId,
        Actor actor,
        uint256 completedAt,
        TaskStatus status
    );

    event DelayJustified(
        uint256 indexed taskId,
        string justification
    );

    event MandatoryTaskChanged(
        uint256 indexed taskId,
        bool isMandatory
    );

    event TurnaroundCertified(
        uint256 actualDeparture,
        uint256 tasksOnTime,
        uint256 lateTasks,
        bytes32 certificationHash
    );

    event BadgeMinted(
        Actor actor,
        address recipient,
        uint256 badgeId
    );

    // ============================================================
    // CONSTRUCTOR
    // ============================================================

    constructor(
        string memory _offChainId,
        string memory _airportCode,
        uint256 _scheduledArrival,
        uint256 _scheduledDeparture
    ) {
        require(_scheduledArrival < _scheduledDeparture, "Invalid schedule");

        // Set admin role to deployer
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(OPS_ROLE, msg.sender);

        // Initialize turnaround info
        turnaroundInfo = TurnaroundInfo({
            offChainId: _offChainId,
            airportCode: _airportCode,
            scheduledArrival: _scheduledArrival,
            scheduledDeparture: _scheduledDeparture,
            actualDeparture: 0,
            isCertified: false,
            certificationHash: bytes32(0)
        });

        // Initialize 27 tasks via TurnaroundTemplates library
        _initializeTasks();

        emit TurnaroundCreated(
            _offChainId,
            _airportCode,
            _scheduledArrival,
            _scheduledDeparture
        );
    }

    // ============================================================
    // TASK EXECUTION
    // ============================================================

    /**
     * @dev Marks a task as completed by the assigned actor
     * @param taskId The task ID (0-26)
     */
    function completeTask(uint256 taskId) external {
        require(taskId < TASK_COUNT, "Invalid task ID");
        require(!turnaroundInfo.isCertified, "Turnaround already certified");

        Task storage task = tasks[taskId];
        require(!task.isCompleted, "Task already completed");
        require(
            msg.sender == actorWallets[task.assignedActor] || hasRole(OPS_ROLE, msg.sender),
            "Not authorized"
        );

        task.isCompleted = true;
        task.completedAt = block.timestamp;

        // Determine if task is on-time or late
        if (block.timestamp <= task.deadline) {
            task.status = TaskStatus.OnTime;
        } else {
            task.status = TaskStatus.Late;
        }

        emit TaskCompleted(taskId, task.assignedActor, block.timestamp, task.status);
    }

    /**
     * @dev Submits a justification for a late task
     * @param taskId The task ID (0-26)
     * @param justification Human-readable reason for delay
     */
    function justifyDelay(uint256 taskId, string calldata justification) external {
        require(taskId < TASK_COUNT, "Invalid task ID");
        Task storage task = tasks[taskId];
        require(task.isCompleted, "Task not completed");
        require(task.status == TaskStatus.Late, "Task not late");
        require(
            msg.sender == actorWallets[task.assignedActor] || hasRole(OPS_ROLE, msg.sender),
            "Not authorized"
        );

        task.justification = justification;

        emit DelayJustified(taskId, justification);
    }

    // ============================================================
    // CERTIFICATION & KPIs
    // ============================================================

    /**
     * @dev Certifies the turnaround after all mandatory tasks are complete
     * @notice Only OPS_ROLE can certify
     */
    function certifyTurnaround() external onlyRole(OPS_ROLE) {
        require(!turnaroundInfo.isCertified, "Already certified");

        // Check all mandatory tasks are complete
        for (uint256 i = 0; i < TASK_COUNT; i++) {
            if (tasks[i].isMandatory) {
                require(tasks[i].isCompleted, "Mandatory task incomplete");
            }
        }

        // Compute KPIs
        (uint256 onTime, uint256 late) = _computeKPIs();

        // Record actual departure time
        turnaroundInfo.actualDeparture = block.timestamp;
        turnaroundInfo.isCertified = true;

        // Generate certification hash
        turnaroundInfo.certificationHash = keccak256(
            abi.encodePacked(
                turnaroundInfo.offChainId,
                turnaroundInfo.actualDeparture,
                onTime,
                late,
                block.timestamp
            )
        );

        emit TurnaroundCertified(
            turnaroundInfo.actualDeparture,
            onTime,
            late,
            turnaroundInfo.certificationHash
        );
    }

    /**
     * @dev Returns KPI metrics for the turnaround
     * @return onTime Number of tasks completed on time
     * @return late Number of unjustified late tasks
     * @return slaBreached Whether the SLA was breached
     */
    function getKPIs() external view returns (
        uint256 onTime,
        uint256 late,
        bool slaBreached
    ) {
        (onTime, late) = _computeKPIs();
        slaBreached = (late > 0); // SLA breached if any unjustified late tasks
    }

    // ============================================================
    // ADMIN FUNCTIONS
    // ============================================================

    /**
     * @dev Sets the wallet address for an operational actor
     * @param actor The actor role
     * @param wallet The wallet address
     */
    function setActorWallet(Actor actor, address wallet) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(wallet != address(0), "Invalid wallet");
        actorWallets[actor] = wallet;
    }

    /**
     * @dev Sets the TurnaroundBadge NFT contract address
     * @param _badgeContract The badge contract address
     */
    function setBadgeContract(address _badgeContract) external onlyRole(DEFAULT_ADMIN_ROLE) {
        badgeContract = _badgeContract;
    }

    /**
     * @dev Changes mandatory status of a task
     * @param taskId The task ID (0-26)
     * @param isMandatory New mandatory status
     */
    function setTaskMandatory(uint256 taskId, bool isMandatory) external onlyRole(OPS_ROLE) {
        require(taskId < TASK_COUNT, "Invalid task ID");
        tasks[taskId].isMandatory = isMandatory;
        emit MandatoryTaskChanged(taskId, isMandatory);
    }

    // ============================================================
    // INTERNAL FUNCTIONS
    // ============================================================

    /**
     * @dev Initializes all 27 tasks with default values
     * @notice In production, this would call TurnaroundTemplates.initialize()
     */
    function _initializeTasks() private {
        // Template: M01-M27 tasks with actors and deadlines
        // Simplified version - production uses TurnaroundTemplates library
        for (uint256 i = 0; i < TASK_COUNT; i++) {
            tasks[i] = Task({
                assignedActor: Actor(i % 6), // Distribute across 6 actors
                deadline: turnaroundInfo.scheduledArrival + (i * 5 minutes),
                isMandatory: true, // All mandatory by default
                status: TaskStatus.Pending,
                isCompleted: false,
                completedAt: 0,
                justification: ""
            });
        }
    }

    /**
     * @dev Computes KPI metrics
     * @return onTime Number of tasks completed on time
     * @return late Number of unjustified late tasks
     */
    function _computeKPIs() private view returns (uint256 onTime, uint256 late) {
        for (uint256 i = 0; i < TASK_COUNT; i++) {
            if (tasks[i].isCompleted) {
                if (tasks[i].status == TaskStatus.OnTime) {
                    onTime++;
                } else if (tasks[i].status == TaskStatus.Late && bytes(tasks[i].justification).length == 0) {
                    late++; // Only count unjustified late tasks
                }
            }
        }
    }

    // ============================================================
    // VIEW FUNCTIONS
    // ============================================================

    /**
     * @dev Returns task details
     * @param taskId The task ID (0-26)
     */
    function getTask(uint256 taskId) external view returns (Task memory) {
        require(taskId < TASK_COUNT, "Invalid task ID");
        return tasks[taskId];
    }

    /**
     * @dev Returns turnaround operational duration in seconds
     */
    function getOperationalDuration() external view returns (uint256) {
        if (!turnaroundInfo.isCertified) return 0;
        return turnaroundInfo.actualDeparture - turnaroundInfo.scheduledArrival;
    }
}
