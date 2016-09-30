const int CTRL_FORWARD = 1;
const int CTRL_BACK = 2;
const int CTRL_LEFT = 4;
const int CTRL_RIGHT = 8;
const int CTRL_JUMP = 16;
const int CTRL_BRAKE = 32;

// Character
const float MOVE_FORCE = 80.0f;
const float INAIR_MOVE_FORCE = 6.0f;
const float BRAKE_FORCE = 20.0f;
const float JUMP_FORCE = 370.0f;
const float INAIR_THRESHOLD_TIME = 0.2f;

// Car
const float ENGINE_POWER = 2300.0f;
const float DOWN_FORCE = 100.0f;
const float MAX_WHEEL_ANGLE = 30.5f;

class GenericAgent: ScriptObject {
    // Character controls.
    Controls controls;
};

class Character : GenericAgent {

    // Grounded flag for movement.
    bool onGround = false;
    // Jump flag.
    bool okToJump = true;
    // In air timer. Due to possible physics inaccuracy, character can be off ground for max. 1/10 second and still be allowed to move.
    float inAirTimer = 0.0f;

    void Start()
    {
        SubscribeToEvent(node, "NodeCollision", "HandleNodeCollision");
    }

    void Load(Deserializer& deserializer)
    {
        controls.yaw = deserializer.ReadFloat();
        controls.pitch = deserializer.ReadFloat();
    }

    void Save(Serializer& serializer)
    {
        serializer.WriteFloat(controls.yaw);
        serializer.WriteFloat(controls.pitch);
    }

    void HandleNodeCollision(StringHash eventType, VariantMap& eventData)
    {
        VectorBuffer contacts = eventData["Contacts"].GetBuffer();

        while (!contacts.eof)
        {
            Vector3 contactPosition = contacts.ReadVector3();
            Vector3 contactNormal = contacts.ReadVector3();
            float contactDistance = contacts.ReadFloat();
            float contactImpulse = contacts.ReadFloat();

            // If contact is below node center and pointing up, assume it's a ground contact
            if (contactPosition.y < (node.position.y + 1.0f))
            {
                float level = contactNormal.y;
                if (level > 0.75)
                    onGround = true;
            }
        }
    }

    void FixedUpdate(float timeStep)
    {
        /// \todo Could cache the components for faster access instead of finding them each frame
        RigidBody@ body = node.GetComponent("RigidBody");
        AnimationController@ animCtrl = node.GetComponent("AnimationController", true);

        // Update the in air timer. Reset if grounded
        if (!onGround)
            inAirTimer += timeStep;
        else
            inAirTimer = 0.0f;
        // When character has been in air less than 1/10 second, it's still interpreted as being on ground
        bool softGrounded = inAirTimer < INAIR_THRESHOLD_TIME;

        // Update movement & animation
        Quaternion rot = node.rotation;
        Vector3 moveDir(0.0f, 0.0f, 0.0f);
        Vector3 velocity = body.linearVelocity;
        // Velocity on the XZ plane
        Vector3 planeVelocity(velocity.x, 0.0f, velocity.z);

        if (controls.IsDown(CTRL_FORWARD))
            moveDir += Vector3(0.0f, 0.0f, 1.0f);
        if (controls.IsDown(CTRL_BACK))
            moveDir += Vector3(0.0f, 0.0f, -1.0f);
        if (controls.IsDown(CTRL_LEFT))
            moveDir += Vector3(-1.0f, 0.0f, 0.0f);
        if (controls.IsDown(CTRL_RIGHT))
            moveDir += Vector3(1.0f, 0.0f, 0.0f);

        // Normalize move vector so that diagonal strafing is not faster
        if (moveDir.lengthSquared > 0.0f)
            moveDir.Normalize();

        // If in air, allow control, but slower than when on ground
        body.ApplyImpulse(rot * moveDir * (softGrounded ? MOVE_FORCE : INAIR_MOVE_FORCE));

        if (softGrounded)
        {
            // When on ground, apply a braking force to limit maximum ground velocity
            Vector3 brakeForce = -planeVelocity * BRAKE_FORCE;
            body.ApplyImpulse(brakeForce);

            // Jump. Must release jump control inbetween jumps
            if (controls.IsDown(CTRL_JUMP))
            {
                if (okToJump)
                {
                    body.ApplyImpulse(Vector3(0.0f, 1.0f, 0.0f) * JUMP_FORCE);
                    okToJump = false;
                    animCtrl.PlayExclusive("Models/Jump01.ani", 0, false, 0.2f);
                }
            }
            else
                okToJump = true;
        }

        if (!onGround)
        {
            animCtrl.PlayExclusive("Models/Jump01.ani", 0, false, 0.2f);
        }
        else
        {
            // Play walk animation if moving on ground, otherwise fade it out
            if (softGrounded && !moveDir.Equals(Vector3(0.0f, 0.0f, 0.0f)))
            {
                animCtrl.PlayExclusive("Models/Run.ani", 0, true, 0.2f);
                // Set walk animation speed proportional to velocity
                animCtrl.SetSpeed("Models/Run.ani", planeVelocity.length * 0.1f);
            }
            else
                animCtrl.PlayExclusive("Models/Idle0.ani", 0, true, 0.2f);

        }

        // Reset grounded flag for next frame
        onGround = false;
    }
    void Init()
    {
        Array<String> bodyobjects = {
            // Main body
            "Models/Dungeon_boy:Adult_male_genitalia.mdl", "Materials/Dungeon_boy:Adult_male_genitalia:Defaultskin.xml",
            // head
            "Models/Dungeon_boy:Adult_male_genitalia.001.mdl", "Materials/Dungeon_boy:Adult_male_genitalia:Defaultskin.xml",
            // hands
            "Models/dungeon-boy-hands.mdl", "Materials/Dungeon_boy:Adult_male_genitalia:Defaultskin.xml",
            // feet
            "Models/dungeon-boy-feet.mdl", "Materials/Dungeon_boy:Adult_male_genitalia:Defaultskin.xml",
            // eyebrows
            "Models/Dungeon_boy:Eyebrow008.mdl", "Materials/Dungeon_boy:Eyebrow008:Eyebrow008.xml",
            "Models/Dungeon_boy:High-poly.mdl", "Materials/Dungeon_boy:High-poly:Eye_brown.xml",
            "Models/Dungeon_boy:Short04.mdl", "Materials/Dungeon_boy:Short04:Short04.xml",
            "Models/Dungeon_boy:Teeth_shape01.mdl", "Materials/Dungeon_boy:Teeth_shape01:Teethmaterial.xml",
            "Models/Dungeon_boy:Tongue01.mdl", "Materials/Dungeon_boy:Tongue01:Tongue01material.xml"
        };
    
        // Clothes
        Array<String> clothobjects = {
            "Models/Dungeon_boy:Male_casualsuit05.001.mdl", "Materials/Dungeon_boy:Male_casualsuit05:Male_casualsuit05.xml",
            "Models/Dungeon_boy:Male_casualsuit05.002.mdl", "Materials/Dungeon_boy:Male_casualsuit05:Male_casualsuit05.xml",
            "Models/Dungeon_boy:Shoes04.mdl", "Materials/Dungeon_boy:Shoes04:Shoes04.xml"
        };
        node.position = Vector3(0.0f, 1.0f, 0.0f);
        Node@ adjNode = node.CreateChild("AdjNode");
        adjNode.rotation = Quaternion(-90, Vector3(0, 1, 0));
        Print("bodyobjects.length: " + String(bodyobjects.length));
        for (uint i = 0; i < bodyobjects.length; i += 2) {
            AnimatedModel@ obj = adjNode.CreateComponent("AnimatedModel");
            Print(String(i));
            Print(String(i) + " material: " +  bodyobjects[i + 1] + " model: " + bodyobjects[i]);
            obj.model = cache.GetResource("Model", bodyobjects[i]);
            if (bodyobjects[i + 1].length > 0)
                obj.material = cache.GetResource("Material", bodyobjects[i + 1]);
            obj.castShadows = true;
            if (i == 0)
                obj.skeleton.GetBone("head").animated = false;	
        }
        for (uint i = 0; i < clothobjects.length; i += 2) {
            AnimatedModel@ obj = adjNode.CreateComponent("AnimatedModel");
            obj.model = cache.GetResource("Model", clothobjects[i]);
            if (clothobjects[i + 1].length > 0)
                obj.material = cache.GetResource("Material", clothobjects[i + 1]);
            obj.castShadows = true;
        }
        adjNode.CreateComponent("AnimationController");
        RigidBody@ body = node.CreateComponent("RigidBody");
        body.collisionLayer = 1;
        body.mass = 70.0f;
        // Set zero angular factor so that physics doesn't turn the character on its own.
        // Instead we will control the character yaw manually
        body.angularFactor = Vector3(0.0f, 0.0f, 0.0f);
    
        // Set the rigidbody to signal collision also when in rest, so that we get ground collisions properly
        body.collisionEventMode = COLLISION_ALWAYS;
    
        // Set a capsule shape for collision
        CollisionShape@ shape = node.CreateComponent("CollisionShape");
        shape.SetCapsule(0.7f, 1.8f, Vector3(0.0f, 0.9f, 0.0f));
    }
};

// Vehicle script object class
//
// When saving, the node and component handles are automatically converted into nodeID or componentID attributes
// and are acquired from the scene when loading. The steering member variable will likewise be saved automatically.
// The Controls object can not be automatically saved, so handle it manually in the Load() and Save() methods

class Vehicle : GenericAgent {
    Node@ frontLeft;
    Node@ frontRight;
    Node@ rearLeft;
    Node@ rearRight;
    Node@ steeringNode;
    Constraint@ frontLeftAxis;
    Constraint@ frontRightAxis;
    RigidBody@ hullBody;
    RigidBody@ frontLeftBody;
    RigidBody@ frontRightBody;
    RigidBody@ rearLeftBody;
    RigidBody@ rearRightBody;

    // Current left/right steering amount (-1 to 1.)
    float steering = 0.0f;

    void Load(Deserializer& deserializer)
    {
        controls.yaw = deserializer.ReadFloat();
        controls.pitch = deserializer.ReadFloat();
    }

    void Save(Serializer& serializer)
    {
        serializer.WriteFloat(controls.yaw);
        serializer.WriteFloat(controls.pitch);
    }

    void Init()
    {
        // This function is called only from the main program when initially creating the vehicle, not on scene load
        Node@ correction_node = node.CreateChild("corection");
        StaticModel@ hullObject = correction_node.CreateComponent("StaticModel");
        StaticModel@ interriorObject = correction_node.CreateComponent("StaticModel");
        StaticModel@ hoodObject = correction_node.CreateComponent("StaticModel");
        Node@ steeringWheelnode = correction_node.CreateChild("steeringWheel");
        steeringNode = steeringWheelnode.CreateChild("steering");
        steeringWheelnode.position = Vector3(0.38, 0.93, -0.55);
        steeringWheelnode.rotation = Quaternion(64.6, 0.0, 0.0);
        StaticModel@ steerObject = steeringNode.CreateComponent("StaticModel");
        Node@ lf_door = correction_node.CreateChild("lf_door");
        lf_door.position = Vector3(0.85f, 0.283f, -1.0);
        Node@ rf_door = correction_node.CreateChild("rf_door");
        rf_door.position = Vector3(-0.85f, 0.283f, -1.0);
        rf_door.scale = Vector3(-1, 1, 1);
        StaticModel@ lf_door_Object = lf_door.CreateComponent("StaticModel");
        StaticModel@ rf_door_Object = rf_door.CreateComponent("StaticModel");
        correction_node.rotation = Quaternion(0, 180, 0);
        correction_node.position = Vector3(0.0, -2.0, 0.0);
        hullBody = node.CreateComponent("RigidBody");
        CollisionShape@ hullShape = node.CreateComponent("CollisionShape");

        /* Lights */
        Node@ fl_light_node = correction_node.CreateChild("fl_light");
        StaticModel@ fl_light_Object = fl_light_node.CreateComponent("StaticModel");
        fl_light_Object.model = cache.GetResource("Model", "Models/car/Models/front_light1.mdl");
        fl_light_Object.material = cache.GetResource("Material", "Models/car/Materials/front_light1.xml");
        fl_light_node.position = Vector3(0.638, 0.652, -2.238);
        Node@ fr_light_node = correction_node.CreateChild("fr_light");
        StaticModel@ fr_light_Object = fr_light_node.CreateComponent("StaticModel");
        fr_light_Object.model = fl_light_Object.model;
        fr_light_Object.materials[0] = fl_light_Object.materials[0].Clone();
        fr_light_Object.materials[0].cullMode = CULL_CW;
        fr_light_Object.materials[0].shadowCullMode = CULL_CW;
        fr_light_node.position = Vector3(-0.638, 0.652, -2.238);
        fr_light_node.scale = Vector3(-1, 1, 1);

//        node.scale = Vector3(1.5f, 1.0f, 3.0f);
        hullObject.model = cache.GetResource("Model", "Models/car/Models/car_hull1.mdl");
        hullObject.material = cache.GetResource("Material", "Models/car/Materials/hull_material.xml");
        hullObject.castShadows = true;
        interriorObject.model = cache.GetResource("Model", "Models/car/Models/car_interrior1.mdl");
        interriorObject.material = cache.GetResource("Material", "Models/car/Materials/car_interrior1.xml");
        interriorObject.castShadows = true;
        hoodObject.model = cache.GetResource("Model", "Models/car/Models/car_hood1.mdl");
        hoodObject.material = cache.GetResource("Material", "Models/car/Materials/hood_material1.xml");
        hoodObject.castShadows = true;
        steerObject.model = cache.GetResource("Model", "Models/car/Models/steering_wheel1.mdl");
        steerObject.material = cache.GetResource("Material", "Models/car/Materials/steering_wheel1.xml");
        steerObject.castShadows = true;
        lf_door_Object.model = cache.GetResource("Model", "Models/car/Models/car_front_door1.mdl");
        lf_door_Object.material = cache.GetResource("Material", "Models/car/Materials/car_front_door1.xml");
        lf_door_Object.castShadows = true;
        rf_door_Object.model = lf_door_Object.model.Clone();
        rf_door_Object.materials[0] = lf_door_Object.materials[0].Clone();
        rf_door_Object.materials[0].cullMode = CULL_CW;
        rf_door_Object.materials[0].shadowCullMode = CULL_CW;
        rf_door_Object.castShadows = true;
        hullShape.SetConvexHull(hullObject.model, 0, Vector3(1, 1, 1), correction_node.position, correction_node.rotation);
        hullBody.mass = 1800.0f;
        hullBody.linearDamping = 0.2f; // Some air resistance
        hullBody.angularDamping = 0.5f;
        hullBody.collisionLayer = 1;

        frontLeft = InitWheel("FrontLeft", Vector3(-0.60f, 0.35f, 1.5f) + correction_node.position);
        frontRight = InitWheel("FrontRight", Vector3(0.60f, 0.35f, 1.5f) + correction_node.position);
        rearLeft = InitWheel("RearLeft", Vector3(-0.60f, 0.35f, -1.4f) + correction_node.position);
        rearRight = InitWheel("RearRight", Vector3(0.60f, 0.35f, -1.4f) + correction_node.position);

        frontLeftAxis = frontLeft.GetComponent("Constraint");
        frontRightAxis = frontRight.GetComponent("Constraint");
        frontLeftBody = frontLeft.GetComponent("RigidBody");
        frontRightBody = frontRight.GetComponent("RigidBody");
        rearLeftBody = rearLeft.GetComponent("RigidBody");
        rearRightBody = rearRight.GetComponent("RigidBody");
    }

    Node@ InitWheel(const String&in name, const Vector3&in offset)
    {
/*
        Node@ wheelNode = node.CreateChild(name);
        StaticModel@ wheelObject = wheelNode.CreateComponent("StaticModel");
        StaticModel@ tireObject = wheelNode.CreateComponent("StaticModel");
        wheelObject.model = cache.GetResource("Model", "Models/car/Models/rim1.mdl");
        wheelObject.material = cache.GetResource("Material", "Models/car/Materials/rim.xml");
        tireObject.model = cache.GetResource("Model", "Models/car/Models/tire1.mdl");
        tireObject.material = cache.GetResource("Material", "Models/car/Materials/tire.xml");
        wheelObject.castShadows = true;
        tireObject.castShadows = true;
//        wheelNode.scale = Vector3(0.8f, 0.8f, 0.8f);
*/
        // Note: do not parent the wheel to the hull scene node. Instead create it on the root level and let the physics
        // constraint keep it together
        Node@ wheelNode = scene.CreateChild(name);
        Node@ tire_node = wheelNode.CreateChild("tire1");
        wheelNode.position = node.LocalToWorld(offset);
        wheelNode.rotation = node.worldRotation * (offset.x >= 0.0f ? Quaternion(0.0f, 0.0f, 0.0f) :
            Quaternion(0.0f, 0.0f, 180.0f));
//        wheelNode.scale = Vector3(0.8f, 0.5f, 0.8f);

        StaticModel@ wheelObject = wheelNode.CreateComponent("StaticModel");
        StaticModel@ tireObject = tire_node.CreateComponent("StaticModel");
        RigidBody@ wheelBody = wheelNode.CreateComponent("RigidBody");
        CollisionShape@ wheelShape = wheelNode.CreateComponent("CollisionShape");
        Constraint@ wheelConstraint = wheelNode.CreateComponent("Constraint");
        Constraint@ wheelSliderConstraint = wheelNode.CreateComponent("Constraint");

        wheelObject.model = cache.GetResource("Model", "Models/car/Models/rim1.mdl");
        wheelObject.material = cache.GetResource("Material", "Models/car/Materials/rim.xml");
        tireObject.model = cache.GetResource("Model", "Models/car/Models/tire1.mdl");
        tireObject.material = cache.GetResource("Material", "Models/car/Materials/tire.xml");
        wheelObject.castShadows = true;
//        wheelShape.SetSphere(0.7f);
        wheelShape.SetCylinder(0.7f, 0.3f,Vector3(0.0, 0.0, 0.0), Quaternion(0.0, 0.0, 90.0));
        wheelBody.friction = 1;
        wheelBody.rollingFriction = 0.7f;
        wheelBody.mass = 10;
        wheelBody.linearDamping = 0.9f; // Some air resistance
        wheelBody.angularDamping = 0.75f; // Could also use rolling friction
//        wheelBody.rollingFriction = 1.0;
        wheelBody.collisionLayer = 1;
        wheelBody.collisionMask = 0xfffffffe;
        wheelConstraint.constraintType = CONSTRAINT_HINGE;
        wheelConstraint.otherBody = node.GetComponent("RigidBody");
        wheelConstraint.worldPosition = wheelNode.worldPosition; // Set constraint's both ends at wheel's location
        wheelConstraint.axis = Vector3(1.0f, 0.0f, 0.0f); // Wheel rotates around its local Y-axis
        wheelConstraint.otherAxis = offset.x >= 0.0f ? Vector3(1.0f, 0.0f, 0.0f) : Vector3(-1.0f, 0.0f, 0.0f); // Wheel's hull axis points either left or right
        wheelConstraint.lowLimit = Vector2(-180.0f, 0.0f); // Let the wheel rotate freely around the axis
        wheelConstraint.highLimit = Vector2(180.0f, 0.0f);
        wheelConstraint.disableCollision = true; // Let the wheel intersect the vehicle hull
        wheelSliderConstraint.constraintType = CONSTRAINT_SLIDER;
        wheelSliderConstraint.otherBody = node.GetComponent("RigidBody");
        wheelSliderConstraint.worldPosition = wheelNode.worldPosition; // Set constraint's both ends at wheel's location
        wheelSliderConstraint.axis = Vector3(0.0f, 1.0f, 0.0f);
        wheelSliderConstraint.otherAxis = Vector3(0.0f, -1.0f, 0.0f);
        wheelSliderConstraint.lowLimit = Vector2(-1.0f, 0.0f);
        wheelSliderConstraint.highLimit = Vector2(1.0f, 0.0f);
        wheelSliderConstraint.disableCollision = true;
        wheelSliderConstraint.enabled = false;

        return wheelNode;
    }

    void FixedUpdate(float timeStep)
    {
        float newSteering = 0.0f;
        float accelerator = 0.0f;
        bool brake_active = false;
        bool on_ground = false;
        Array<Node@> wheels = {frontLeft, frontRight, rearLeft, rearRight};
        Ray ground(node.position, Vector3(0.0, -1.0, 0.0));
        Scene@ scene = renderer.viewports[0].scene;
        PhysicsRaycastResult result = scene.physicsWorld.RaycastSingle(ground, 1.0, 2);
        if (result.body !is null)
            on_ground = true;

        if (controls.IsDown(CTRL_LEFT))
            newSteering = -1.0f;
        if (controls.IsDown(CTRL_RIGHT))
            newSteering = 1.0f;
        if (controls.IsDown(CTRL_FORWARD))
            accelerator = 1.0f;
        if (controls.IsDown(CTRL_BACK))
            accelerator = -0.5f;
        if (controls.IsDown(CTRL_BRAKE)) {
            if (!brake_active) {
                for (int i = 0; i < wheels.length; i++) {
                    RigidBody@ b = wheels[i].GetComponent("RigidBody");
                    b.rollingFriction = 1.0;
                    if (on_ground) {
                        b.linearDamping = 1.0;
                        b.angularDamping = 1.0;
                    }
                    b.restitution = 1.0;
//                    b.kinematic = true;
                    Constraint@ wheelc = wheels[i].GetComponent("Constraint");
                    wheelc.lowLimit = Vector2(-10, 0);
                    wheelc.highLimit = Vector2(10, 0);
                    wheelc.enabled = true;
                }
                brake_active = true;
            }
//            if (hullBody.linearVelocity.length < 0.5) {
//                hullBody.linearDamping = 1.0f;
//                hullBody.angularDamping = 1.0;
//            }
           if (on_ground) {
               hullBody.restitution = 1.0;
               hullBody.linearDamping = 1.0;
           }
        } else {
            if (brake_active) {
                for (int i = 0; i < wheels.length; i++) {
                    RigidBody@ b = wheels[i].GetComponent("RigidBody");
                    b.rollingFriction = 1.0;
                    b.linearDamping = 0.2f;
                    b.angularDamping = 0.75f;
//                    b.kinematic = false;
                    Constraint@ wheelc = wheels[i].GetComponent("Constraint");
                    wheelc.lowLimit = Vector2(-180.0f, 0.0f);
                    wheelc.highLimit = Vector2(180.0f, 0.0f);
                    wheelc.enabled = true;
                }
                hullBody.linearDamping = 0.2f;
                hullBody.angularDamping = 0.5f;
                brake_active = false;
            }
        }

        // When steering, wake up the wheel rigidbodies so that their orientation is updated
        if (newSteering != 0.0f)
        {
            frontLeftBody.Activate();
            frontRightBody.Activate();
            steering = steering * 0.95f + newSteering * 0.05f;
        }
        else
            steering = steering * 0.8f + newSteering * 0.2f;

        steeringNode.rotation = Quaternion(0, steering * 180, 0);

        Quaternion steeringRot(0.0f, steering * MAX_WHEEL_ANGLE, 0.0f);

        frontLeftAxis.otherAxis = steeringRot * Vector3(-1.0f, 0.0f, 0.0f);
        frontRightAxis.otherAxis = steeringRot * Vector3(1.0f, 0.0f, 0.0f);

        if (accelerator != 0.0f)
        {
            // Torques are applied in world space, so need to take the vehicle & wheel rotation into account
            Vector3 torqueVec = Vector3(ENGINE_POWER * accelerator, 0.0f, 0.0f);

            frontLeftBody.ApplyTorque(node.rotation * steeringRot * torqueVec);
            frontRightBody.ApplyTorque(node.rotation * steeringRot * torqueVec);
            rearLeftBody.ApplyTorque(node.rotation * torqueVec);
            rearRightBody.ApplyTorque(node.rotation * torqueVec);
        }

        // Apply downforce proportional to velocity
        Vector3 localVelocity = hullBody.rotation.Inverse() * hullBody.linearVelocity;
//        hullBody.ApplyForce(hullBody.rotation * Vector3(0.0f, -1.0f, 0.0f) * Abs(localVelocity.z) * DOWN_FORCE);
    }
}

