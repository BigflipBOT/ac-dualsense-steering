-- If you want to use pad, uncomment:
-- require('shared/dualsense/grab').pad(true)
-- ^ doesn't quite work?

local aiIni = ac.INIConfig.carData(car.index, 'ai.ini')
local rpmUp = aiIni:get('GEARS', 'UP', 9000)
local rpmDown = aiIni:get('GEARS', 'DOWN', 6000)

local step = 0
local stepmax = ScriptSettings.STEPMAX
local gyroSmooth = 0

function script.update(dt)
  local state = ac.getJoypadState()

  step = step + 1
  if step > 100 then
    step = 0
  end

  if state.gamepadType == ac.GamepadType.DualSense then
    local rpm = (car.rpm - rpmDown) / (rpmUp - rpmDown)
    local ds = ac.getDualSense(state.gamepadIndex)

    -- ###Adding gyroscope to steering
    if ScriptSettings.GYROSCOPE then
      gyroSmooth = math.applyLag(gyroSmooth, state.ffb * 0.05 + ds.gyroscope.x * math.lerp(0.2, 1.5, math.lerpInvSat(ds.gyroscope.z, 0.1, -0.3)), 0.8, dt)
      state.steer = math.clampN(state.steer - gyroSmooth * math.lerpInvSat(state.speedKmh, 1, 5), -1, 1)
    end

    -- ### Gamepad vibrations

    -- Analyzing surface for estimating vibrations
    local speedMult = math.lerpInvSat(state.speedKmh, 50, 100)
    local bump, dirt = 0, 0
    for i = 0, 3 do
      local mult = car.wheels[i].loadK
      dirt = dirt + car.wheels[i].surfaceDirt * mult
      bump = bump + math.lerpInvSat(car.wheels[i].contactNormal.y, 0.97, 0.8) * mult
    end

    -- Major vibrations on the left
    state.vibrationLeft = speedMult
      * math.max(state.surfaceVibrationGainLeft, state.surfaceVibrationGainRight)
    state.vibrationLeft = math.max(state.vibrationLeft, car.absInAction and 0.1 or 0)
    state.vibrationLeft = step % 7 == 1 and math.max(state.vibrationLeft, bump * speedMult) or state.vibrationLeft

    -- Minor vibrations on the right
    state.vibrationRight = step % 4 == 0 and math.saturateN(rpm * 10 - 8.5) * 0.01 or 0
    state.vibrationRight = step % 5 == 3 and math.max(state.vibrationRight, dirt * speedMult * 0.1) or state.vibrationRight

    -- ### Adaptive triggers
    local frontSlip = math.max(state.ndSlipL, state.ndSlipR)
    local rearSlip = math.max(state.ndSlipRL, state.ndSlipRR)

    -- First attempt: keep resistance until grip is lost
    -- if rearSlip < 1 then
    --   ac.setDualSenseTriggerExtendedEffect(1, 0, rearSlip, rearSlip, rearSlip, car.absInAction and 1 or 0, true)
    -- else
    --   ac.setDualSenseTriggerNoEffect(1)
    -- end

    -- if frontSlip < 1 then
    --   ac.setDualSenseTriggerExtendedEffect(0, 0, frontSlip, frontSlip, frontSlip, car.tractionControlInAction and 1 or 0, true)
    -- else
    --   ac.setDualSenseTriggerNoEffect(0)
    -- end
    -----------------------------------------------------------------------------------------------

    -- Second attempt: resistance increases to try and prevent losing traction
    frontSlip = math.lerpInvSat(frontSlip, 0.9, 1)
    rearSlip = math.lerpInvSat(rearSlip, 0.9, 1)

    if rearSlip > 0 then
      ac.setDualSenseTriggerContinuousResitanceEffect(1, 0, rearSlip)
    else
      ac.setDualSenseTriggerNoEffect(1)
    end

    -- if frontSlip > 0 then
    --   ac.setDualSenseTriggerContinuousResitanceEffect(0, 0, frontSlip)
    -- else
    --   ac.setDualSenseTriggerNoEffect(0)
    -- end
    ------------------------------------------------------------

    -- A complete mess: transfer steering FFB to triggers
    -- if state.ffb > 0 then
    --   ac.setDualSenseTriggerContinuousResitanceEffect(1, 0, state.ffb)
    -- else
    --   ac.setDualSenseTriggerNoEffect(1)
    -- end

    -- if state.ffb < 0 then
    --   ac.setDualSenseTriggerContinuousResitanceEffect(0, 0, state.ffb)
    -- else
    --   ac.setDualSenseTriggerNoEffect(0)
    -- end


  end

end

