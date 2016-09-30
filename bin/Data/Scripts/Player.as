const float TOUCH_SENSITIVITY = 2;
bool touchEnabled = false; // Flag to indicate whether touch input has been enabled
bool in_vehicle = false;
bool firstPerson = false; // First person camera flag
/* Vehicle camera distance */
const float CAMERA_DISTANCE = 2.0f;
const float YAW_SENSITIVITY = 0.1f;
void handle_player_update(Node@ control, Node@ cameraNode, float timeStep)
{
    GenericAgent@ agent = cast<GenericAgent>(control.scriptObject);
    if (agent is null)
        return;
    // Clear previous controls
    agent.controls.Set(CTRL_FORWARD | CTRL_BACK | CTRL_LEFT | CTRL_RIGHT | CTRL_JUMP, false);
    
    // Update controls using keys (desktop)
    if (ui.focusElement is null) {
        agent.controls.Set(CTRL_FORWARD, input.keyDown[KEY_W]);
        agent.controls.Set(CTRL_BACK, input.keyDown[KEY_S]);
        agent.controls.Set(CTRL_LEFT, input.keyDown[KEY_A]);
        agent.controls.Set(CTRL_RIGHT, input.keyDown[KEY_D]);
        agent.controls.Set(CTRL_JUMP, input.keyDown[KEY_SPACE]);
        if (in_vehicle) {
            // Limit pitch
            agent.controls.pitch = Clamp(agent.controls.pitch, 0.0f, 80.0f);

            Vehicle@ vehicle = cast<Vehicle>(control.scriptObject);
            if (vehicle is null)
                return;
        } else {
            // Limit pitch
            agent.controls.pitch = Clamp(agent.controls.pitch, -80.0f, 80.0f);
            // Set rotation already here so that it's updated every rendering frame instead of every physics frame
            control.rotation = Quaternion(agent.controls.yaw, Vector3(0.0f, 1.0f, 0.0f));
            // Switch between 1st and 3rd person
            if (input.keyPress[KEY_F])
                firstPerson = !firstPerson;
            }
        // Add yaw & pitch from the mouse motion. Used only for the camera, does not affect motion
        if (touchEnabled)
        {
            for (uint i = 0; i < input.numTouches; ++i)
            {
                TouchState@ state = input.touches[i];
                if (state.touchedElement is null) // Touch on empty space
                {
                    Camera@ camera = cameraNode.GetComponent("Camera");
                    if (camera is null)
                        return;

                    agent.controls.yaw += TOUCH_SENSITIVITY * camera.fov / graphics.height * state.delta.x;
                    agent.controls.pitch += TOUCH_SENSITIVITY * camera.fov / graphics.height * state.delta.y;
                }
            }
        }
        else
        {
            agent.controls.yaw += input.mouseMoveX * YAW_SENSITIVITY;
            agent.controls.pitch += input.mouseMoveY * YAW_SENSITIVITY;
        }
    } else
        agent.controls.Set(CTRL_FORWARD | CTRL_BACK | CTRL_LEFT | CTRL_RIGHT, false);
}

void VehicleCameraUpdate(Scene@ scene, Node@ control, Node@ camera_node, float timeStep)
{
    if (control is null)
        return;

    Vehicle@ vehicle = cast<Vehicle>(control.scriptObject);
    if (vehicle is null)
        return;
    // Physics update has completed. Position camera behind vehicle
    Quaternion dir(control.rotation.yaw, Vector3(0.0f, 1.0f, 0.0f));
    dir = dir * Quaternion(vehicle.controls.yaw, Vector3(0.0f, 1.0f, 0.0f));
    dir = dir * Quaternion(vehicle.controls.pitch, Vector3(1.0f, 0.0f, 0.0f));

    Vector3 cameraTargetPos = control.position - dir * Vector3(0.0f, 0.0f, CAMERA_DISTANCE);
    Vector3 cameraStartPos = control.position;
    RigidBody@ b = control.GetComponent("RigidBody");
    float MAX_SPEED = 80;
    float speed = Clamp(b.linearVelocity.length, 0.0, MAX_SPEED);
    float newfov = 50.0 + 120 * speed / MAX_SPEED;
    Camera@ cam = camera_node.GetComponent("Camera");
    cam.fov = cam.fov * 0.9 + newfov * 0.1;

    // Raycast camera against static objects (physics collision mask 2)
    // and move it closer to the vehicle if something in between
    Ray cameraRay(cameraStartPos, (cameraTargetPos - cameraStartPos).Normalized());
    float cameraRayLength = (cameraTargetPos - cameraStartPos).length;
    bool have_bottom = false;
    PhysicsRaycastResult result = scene.physicsWorld.RaycastSingle(cameraRay, cameraRayLength, 2);
    if (result.body !is null) {
//        Print("hit layer " + String(result.body.collisionLayer));
//        cameraTargetPos = cameraStartPos + cameraRay.direction * (result.distance - 0.5f);
    }
    result = scene.physicsWorld.RaycastSingle(cameraRay, cameraRayLength, 1);
    if (result.body !is null) {
//        Print("hit layer " + String(result.body.collisionLayer));
        cameraTargetPos -= cameraRay.direction * (result.distance);
    }
    Ray bottom_ray(cameraTargetPos, Vector3(0, -1, 0));
    result = scene.physicsWorld.RaycastSingle(bottom_ray, CAMERA_DISTANCE * 2, 2);
    if (result.body !is null) {
        if (result.distance < 3.0)
            cameraTargetPos.y += 6.0 - result.distance;
//        Print("hit layer bottom " + String(result.body.collisionLayer));
        have_bottom = true;
    }
    Ray top_ray(cameraTargetPos, Vector3(0, 1, 0));
    result = scene.physicsWorld.RaycastSingle(bottom_ray, CAMERA_DISTANCE * 2, 2);
    if (result.body !is null && !have_bottom) {
        cameraTargetPos.y = camera_node.position.y;
//        Print("hit layer top " + String(result.body.collisionLayer));
    }
    if ((control.position - cameraTargetPos).length < CAMERA_DISTANCE)
        cameraTargetPos -= (control.position - cameraTargetPos).Normalized() * (CAMERA_DISTANCE + 0.5);
    Quaternion foo = camera_node.rotation.Slerp(dir, timeStep );
    camera_node.position += (cameraTargetPos - camera_node.position) * timeStep;

//    if (cameraTargetPos.y < 5.0)
//        cameraTargetPos.y = 5.0;

//    cameraNode.worldRotation = foo; // cameraNode.rotation + (dir - cameraNode.rotation);
    Node@ tmpCam = Node();
    tmpCam.position = camera_node.position;
    tmpCam.LookAt(control.position);
    camera_node.rotation = foo.Slerp(tmpCam.rotation, timeStep);
}

void CharacterCameraUpdate(Scene@ scene, Node@ control, Node@ camera_node, float timeStep)
{
    if (control is null)
        return;
    Character@ character = cast<Character>(control.scriptObject);
    if (character is null)
        return;
    // Get camera lookat dir from character yaw + pitch
    Quaternion rot = control.rotation;
    Quaternion dir = rot * Quaternion(character.controls.pitch, Vector3(1.0f, 0.0f, 0.0f));

    // Turn head to camera pitch, but limit to avoid unnatural animation
    Node@ headNode = control.GetChild("head", true);
    float limitPitch = Clamp(character.controls.pitch, -45.0f, 45.0f);
    Quaternion headDir = rot * Quaternion(limitPitch, Vector3(1.0f, 0.0f, 0.0f));
    // This could be expanded to look at an arbitrary target, now just look at a point in front
    Vector3 headWorldTarget = headNode.worldPosition + headDir * Vector3(0.0f, 0.0f, -1.0f);
    headNode.LookAt(headWorldTarget, Vector3(0.0f, 1.0f, 0.0f));
    if (firstPerson)
    {
        // First person camera: position to the head bone + offset slightly forward & up
        camera_node.position = headNode.worldPosition + rot * Vector3(0.0f, 0.15f, 0.2f);
        camera_node.rotation = dir;
    }
    else
    {
        // Third person camera: position behind the character
        Vector3 aimPoint = control.position + rot * Vector3(0.0f, 1.7f, 0.0f); // You can modify x Vector3 value to translate the fixed character position (indicative range[-2;2])

        // Collide camera ray with static physics objects (layer bitmask 2) to ensure we see the character properly
        Vector3 rayDir = dir * Vector3(0.0f, 0.0f, -1.0f); // For indoor scenes you can use dir * Vector3(0.0, 0.0, -0.5) to prevent camera from crossing the walls
        float rayDistance = 5.0;
        PhysicsRaycastResult result = scene.physicsWorld.RaycastSingle(Ray(aimPoint, rayDir), rayDistance, 2);
        if (result.body !is null)
            rayDistance = Min(rayDistance, result.distance);
        rayDistance = Clamp(rayDistance, 1.0, 5.0);

        camera_node.position = aimPoint + rayDir * rayDistance;
        camera_node.rotation = dir;
    }
}


