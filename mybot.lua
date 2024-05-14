LatestGameState = LatestGameState or nil
InAction = InAction or false -- Prevents the agent from taking multiple actions at once.
local Game = "0rVZYFxvfJpO__EfOz0_PUQ3GFE9kEaES0GkUDNXjvE"
-- Decides the next action based on proximity, energy, and speed
function decideNextAction()
    local player = LatestGameState.Players[ao.id]
    local targetInRange = false
    local speedFactor = 0.5 -- Adjust this value to represent the player's speed

    -- Calculate the expected utility of attacking
    local expectedUtility = function(energy, distance, speed)
        -- Incorporate speed into the utility calculation
        return energy * (1 - distance / 40) * speed
    end

    local bestMove = nil
    local bestUtility = -math.huge

    for target, state in pairs(LatestGameState.Players) do
        if target ~= ao.id then
            local distance = math.sqrt((player.x - state.x)^2 + (player.y - state.y)^2)
            if inRange(player.x, player.y, state.x, state.y, 1) then
                targetInRange = true
                -- Include speed in the utility calculation
                local utility = expectedUtility(player.energy, distance, speedFactor)
                if utility > bestUtility then
                    bestUtility = utility
                    bestMove = "Attack"
                end
            end
        end
    end

    -- Check if the player should attack quickly based on the utility and speed
    if player.energy > 5 and targetInRange and bestMove == "Attack" then
        print("Player in range. Attacking quickly.")
        -- Send the attack command with a speed factor
        ao.send({ Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(player.energy * speedFactor) })
    else
        print("No player in range or insufficient energy. Moving randomly.")
        local directionMap = {"Up", "Down", "Left", "Right", "UpRight", "UpLeft", "DownRight", "DownLeft"}
        local randomIndex = math.random(#directionMap)
        -- Move quickly in a random direction
        ao.send({ Target = Game, Action = "PlayerMove", Player = ao.id, Direction = directionMap[randomIndex], Speed = speedFactor })
    end
end


-- Handler to print game announcements directly in the terminal.

Handlers.add(
  "PrintAnnouncements",
  Handlers.utils.hasMatchingTag("Action", "Announcement"),
  function (msg)
    print(msg.Event .. ": " .. msg.Data)
  end
)
Handlers.add(
  "HandleAnnouncements",
  Handlers.utils.hasMatchingTag("Action", "Announcement"),
  function (msg)
    ao.send({Target = Game, Action = "GetGameState"})
    print(msg.Event .. ": " .. msg.Data)
  end
)
-- Handler to update the game state upon receiving game state information.

Handlers.add(
  "UpdateGameState",
  Handlers.utils.hasMatchingTag("Action", "GameState"),
  function (msg)
    local json = require("json")
    LatestGameState = json.decode(msg.Data)
    ao.send({Target = ao.id, Action = "UpdatedGameState"})
    print("Game state updated. Print \'LatestGameState\' for detailed view.")
  end
)
Handlers.add(
  "decideNextAction",
  Handlers.utils.hasMatchingTag("Action", "UpdatedGameState"),
  function ()
    if LatestGameState.GameMode ~= "Playing" then
      return
    end
    print("Deciding next action.")
    decideNextAction()
  end
)
-- Handler to automatically attack when hit by another player.

Handlers.add(
    "ReturnAttack",
    Handlers.utils.hasMatchingTag("Action", "Hit"),
    function (msg)
        local playerEnergy = LatestGameState.Players[ao.id].energy
        local opponentId = msg.Player -- Extract the opponent's ID from the message

        if playerEnergy == undefined then
            print("Unable to read energy.")
            ao.send({ Target = Game, Action = "Attack-Failed", Reason = "Unable to read energy." })
        elseif playerEnergy == 0 then
            print("Player has insufficient energy.")
            ao.send({ Target = Game, Action = "Attack-Failed", Reason = "Player has no energy." })
        else
            -- Advanced Techniques:
            -- 1. Game Theory: Mixed strategies for return attacks.
            --    Introduce randomness to keep opponents guessing.
            local randomChoice = math.random() < 0.5
            if randomChoice then
                print("Randomly choosing not to attack this time.")
            else
                print("Returning attack against opponent " .. opponentId)
                ao.send({ Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(playerEnergy) })
            end
        end

        InAction = false
        ao.send({ Target = ao.id, Action = "Tick" })
    end
)
Handlers.add("GetGameStateOnTick", Handlers.utils.hasMatchingTag("Action", "Tick"), function ()
  if not InAction then
    InAction = true
    ao.send({Target = Game, Action = "GetGameState"})
  end
end)
-- Handler to automate payment confirmation when waiting period starts.

Handlers.add(
  "AutoPay",
  Handlers.utils.hasMatchingTag("Action", "AutoPay"),
  function (msg)
    print("Auto-paying confirmation fees.")
    ao.send({ Target = Game, Action = "Transfer", Recipient = Game, Quantity = "1000"})
  end
)