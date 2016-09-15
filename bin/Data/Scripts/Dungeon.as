#include "Scripts/Road.as"
#include "Scripts/CreateModels.as"

Scene@ sc;
Node@ cam_node;
Node@ charNode;

const int CTRL_FORWARD = 1;
const int CTRL_BACK = 2;
const int CTRL_LEFT = 4;
const int CTRL_RIGHT = 8;
const int CTRL_JUMP = 16;

const float MOVE_FORCE = 0.8f;
const float INAIR_MOVE_FORCE = 0.02f;
const float BRAKE_FORCE = 0.2f;
const float JUMP_FORCE = 7.0f;
const float YAW_SENSITIVITY = 0.1f;
const float INAIR_THRESHOLD_TIME = 0.1f;
bool firstPerson = false; // First person camera flag

class Character : ScriptObject {
    // Character controls.
    Controls controls;
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
};

void HandleKeyUp(StringHash eventType, VariantMap& eventData)
{
    int key = eventData["Key"].GetInt();

    // Close console (if open) or exit when ESC is pressed
    if (key == KEY_ESCAPE)
    {
        if (console.visible)
            console.visible = false;
        engine.Exit();
    }
}

void HandleKeyDown(StringHash eventType, VariantMap& eventData)
{
    int key = eventData["Key"].GetInt();

    // Toggle console with F1
    if (key == KEY_F1)
        console.Toggle();
        
    // Toggle debug HUD with F2
    else if (key == KEY_F2)
        debugHud.ToggleAll();

    // Common rendering quality controls, only when UI has no focused element
    else if (ui.focusElement is null)
    {
        // Texture quality
        if (key == '1')
        {
            int quality = renderer.textureQuality;
            ++quality;
            if (quality > QUALITY_HIGH)
                quality = QUALITY_LOW;
            renderer.textureQuality = quality;
        }

        // Material quality
        else if (key == '2')
        {
            int quality = renderer.materialQuality;
            ++quality;
            if (quality > QUALITY_HIGH)
                quality = QUALITY_LOW;
            renderer.materialQuality = quality;
        }

        // Specular lighting
        else if (key == '3')
            renderer.specularLighting = !renderer.specularLighting;

        // Shadow rendering
        else if (key == '4')
            renderer.drawShadows = !renderer.drawShadows;

        // Shadow map resolution
        else if (key == '5')
        {
            int shadowMapSize = renderer.shadowMapSize;
            shadowMapSize *= 2;
            if (shadowMapSize > 2048)
                shadowMapSize = 512;
            renderer.shadowMapSize = shadowMapSize;
        }

        // Shadow depth and filtering quality
        else if (key == '6')
        {
            ShadowQuality quality = renderer.shadowQuality;
            quality = ShadowQuality(quality + 1);
            if (quality > SHADOWQUALITY_BLUR_VSM)
                quality = SHADOWQUALITY_SIMPLE_16BIT;
            renderer.shadowQuality = quality;
        }

        // Occlusion culling
        else if (key == '7')
        {
            bool occlusion = renderer.maxOccluderTriangles > 0;
            occlusion = !occlusion;
            renderer.maxOccluderTriangles = occlusion ? 5000 : 0;
        }

        // Instancing
        else if (key == '8')
            renderer.dynamicInstancing = !renderer.dynamicInstancing;

        // Take screenshot
        else if (key == '9')
        {
            Image@ screenshot = Image();
            graphics.TakeScreenShot(screenshot);
            // Here we save in the Data folder with date and time appended
            screenshot.SavePNG(fileSystem.programDir + "Data/Screenshot_" +
                time.timeStamp.Replaced(':', '_').Replaced('.', '_').Replaced(' ', '_') + ".png");
        }
    }
}
/*
void InitMouseMode(MouseMode mode)
{
  useMouseMode_ = mode;

    if (GetPlatform() != "Web")
    {
      if (useMouseMode_ == MM_FREE)
          input.mouseVisible = true;

      if (useMouseMode_ != MM_ABSOLUTE)
      {
          input.mouseMode = useMouseMode_;
          if (console.visible)
              input.SetMouseMode(MM_ABSOLUTE, true);
      }
    }
    else
    {
        input.mouseVisible = true;
        SubscribeToEvent("MouseButtonDown", "HandleMouseModeRequest");
        SubscribeToEvent("MouseModeChanged", "HandleMouseModeChange");
    }
}
*/

Node@ CreateCharacter()
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
    charNode = sc.CreateChild("Char");
    charNode.position = Vector3(0.0f, 1.0f, 0.0f);
    Node@ adjNode = charNode.CreateChild("AdjNode");
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
    RigidBody@ body = charNode.CreateComponent("RigidBody");
    body.collisionLayer = 1;
    body.mass = 1.0f;
    // Set zero angular factor so that physics doesn't turn the character on its own.
    // Instead we will control the character yaw manually
    body.angularFactor = Vector3(0.0f, 0.0f, 0.0f);

    // Set the rigidbody to signal collision also when in rest, so that we get ground collisions properly
    body.collisionEventMode = COLLISION_ALWAYS;

    // Set a capsule shape for collision
    CollisionShape@ shape = charNode.CreateComponent("CollisionShape");
    shape.SetCapsule(0.7f, 1.8f, Vector3(0.0f, 0.9f, 0.0f));

    // Create the character logic object, which takes care of steering the rigidbody
    charNode.CreateScriptObject(scriptFile, "Character");
    return charNode;
}
void Start()
{
    graphics.windowTitle = "Dungeon";
    RoadGen roads = RoadGen();
    engine.maxFps = 60.0;
    roads.add(ITEM_CITY, RoadRect(-500, -500, 500, 500));
    roads.print_queue();
    roads.print_result();
    Node@ roads_node = roads.build();
    roads.print_queue();
    roads.print_result();
    // Get default style
    XMLFile@ xmlFile = cache.GetResource("XMLFile", "UI/DefaultStyle.xml");
    if (xmlFile is null)
        return;

    // Create console
    Console@ console = engine.CreateConsole();
    console.defaultStyle = xmlFile;
    console.background.opacity = 0.8f;

    // Create debug HUD
    DebugHud@ debugHud = engine.CreateDebugHud();
    debugHud.defaultStyle = xmlFile;
    SubscribeToEvent("KeyDown", "HandleKeyDown");
    sc = Scene();
    sc.CreateComponent("Octree");
    sc.CreateComponent("PhysicsWorld");
    sc.CreateComponent("DebugRenderer");
    sc.physicsWorld.DrawDebugGeometry(true);
    renderer.DrawDebugGeometry(true);
    cam_node = Node();
    Camera@ camera = cam_node.CreateComponent("Camera");
    camera.farClip = 30.0f;
    renderer.viewports[0] = Viewport(sc, camera);
    Node@ zoneNode = sc.CreateChild("Zone");
    Zone@ zone = zoneNode.CreateComponent("Zone");
    zone.boundingBox = BoundingBox(-1000.0f, 1000.0f);
    zone.ambientColor = Color(0.15f, 0.15f, 0.15f);
    zone.fogColor = Color(0.5f, 0.5f, 0.7f);
    zone.fogStart = 100.0f;
    zone.fogEnd = 300.0f;
    // Create a directional light to the world. Enable cascaded shadows on it
    Node@ lightNode = sc.CreateChild("DirectionalLight");
    lightNode.direction = Vector3(0.6f, -1.0f, 0.8f);
    Light@ light = lightNode.CreateComponent("Light");
    light.lightType = LIGHT_DIRECTIONAL;
    light.castShadows = true;
    light.shadowBias = BiasParameters(0.00025f, 0.5f);
    // Set cascade splits at 10, 50 and 200 world units, fade shadows out at 80% of maximum shadow distance
    light.shadowCascade = CascadeParameters(10.0f, 50.0f, 200.0f, 0.0f, 0.8f);

    Node@ floorNode = sc.CreateChild("Floor");
    floorNode.position = Vector3(0.0f, -0.5f, 0.0f);
    floorNode.scale = Vector3(200.0f, 1.0f, 200.0f);
    StaticModel@ object = floorNode.CreateComponent("StaticModel");
    object.model = cache.GetResource("Model", "Models/Box.mdl");
    object.material = cache.GetResource("Material", "Materials/Stone.xml");

    RigidBody@ body = floorNode.CreateComponent("RigidBody");
    // Use collision layer bit 2 to mark world scenery. This is what we will raycast against to prevent camera from going
    // inside geometry
    body.collisionLayer = 2;
    CollisionShape@ shape = floorNode.CreateComponent("CollisionShape");
    shape.SetBox(Vector3(1.0f, 1.0f, 1.0f));
    Cube@ sm = Cube();
    sc.AddChild(sm.node);
    Cube@ sm1 = Cube();
    sc.AddChild(sm1.node);
    Cube@ sm2 = Cube();
    sc.AddChild(sm2.node);
    Cube@ sm3 = Cube();
    sc.AddChild(sm3.node);
    sm.node.position = Vector3(3.0, 2.0, 3.0);
    sm1.node.position = Vector3(3.0, 2.0, -3.0);
    sm2.node.position = Vector3(-3.0, 2.0, 3.0);
    sm3.node.position = Vector3(-3.0, 2.0, -3.0);
    sc.AddChild(roads_node);

    // Subscribe to Update event for setting the character controls before physics simulation
    SubscribeToEvent("Update", "HandleUpdate");

    // Subscribe to PostUpdate event for updating the camera position after physics simulation
    SubscribeToEvent("PostUpdate", "HandlePostUpdate");
    SubscribeToEvent("PostRenderUpdate", "HandlePostRenderUpdate");

    // Character
    CreateCharacter();
}

void HandlePostRenderUpdate()
{
    renderer.DrawDebugGeometry(false);
}

void HandlePostUpdate(StringHash eventType, VariantMap& eventData)
{
    if (charNode is null)
        return;

    Character@ character = cast<Character>(charNode.scriptObject);
    if (character is null)
        return;
    // Get camera lookat dir from character yaw + pitch
    Quaternion rot = charNode.rotation;
    Quaternion dir = rot * Quaternion(character.controls.pitch, Vector3(1.0f, 0.0f, 0.0f));

    // Turn head to camera pitch, but limit to avoid unnatural animation
    Node@ headNode = charNode.GetChild("head", true);
    float limitPitch = Clamp(character.controls.pitch, -45.0f, 45.0f);
    Quaternion headDir = rot * Quaternion(limitPitch, Vector3(1.0f, 0.0f, 0.0f));
    // This could be expanded to look at an arbitrary target, now just look at a point in front
    Vector3 headWorldTarget = headNode.worldPosition + headDir * Vector3(0.0f, 0.0f, -1.0f);
    headNode.LookAt(headWorldTarget, Vector3(0.0f, 1.0f, 0.0f));
    if (firstPerson)
    {
        // First person camera: position to the head bone + offset slightly forward & up
        cam_node.position = headNode.worldPosition + rot * Vector3(0.0f, 0.15f, 0.2f);
        cam_node.rotation = dir;
    }
    else
    {
        // Third person camera: position behind the character
        Vector3 aimPoint = charNode.position + rot * Vector3(0.0f, 1.7f, 0.0f); // You can modify x Vector3 value to translate the fixed character position (indicative range[-2;2])

        // Collide camera ray with static physics objects (layer bitmask 2) to ensure we see the character properly
        Vector3 rayDir = dir * Vector3(0.0f, 0.0f, -1.0f); // For indoor scenes you can use dir * Vector3(0.0, 0.0, -0.5) to prevent camera from crossing the walls
        float rayDistance = 5.0;
        PhysicsRaycastResult result = sc.physicsWorld.RaycastSingle(Ray(aimPoint, rayDir), rayDistance, 2);
        if (result.body !is null)
            rayDistance = Min(rayDistance, result.distance);
        rayDistance = Clamp(rayDistance, 1.0, 5.0);

        cam_node.position = aimPoint + rayDir * rayDistance;
        cam_node.rotation = dir;
    }
}

void HandleUpdate(StringHash eventType, VariantMap& eventData)
{
    if (charNode is null)
        return;

    Character@ character = cast<Character>(charNode.scriptObject);
    if (character is null)
        return;

    // Clear previous controls
    character.controls.Set(CTRL_FORWARD | CTRL_BACK | CTRL_LEFT | CTRL_RIGHT | CTRL_JUMP, false);

    // Update controls using keys (desktop)
    if (ui.focusElement is null)
    {
        character.controls.Set(CTRL_FORWARD, input.keyDown[KEY_W]);
        character.controls.Set(CTRL_BACK, input.keyDown[KEY_S]);
        character.controls.Set(CTRL_LEFT, input.keyDown[KEY_A]);
        character.controls.Set(CTRL_RIGHT, input.keyDown[KEY_D]);
        character.controls.Set(CTRL_JUMP, input.keyDown[KEY_SPACE]);

        // Add character yaw & pitch from the mouse motion or touch input
        character.controls.yaw += input.mouseMoveX * YAW_SENSITIVITY;
        character.controls.pitch += input.mouseMoveY * YAW_SENSITIVITY;
        // Limit pitch
        character.controls.pitch = Clamp(character.controls.pitch, -80.0f, 80.0f);
        // Set rotation already here so that it's updated every rendering frame instead of every physics frame
        charNode.rotation = Quaternion(character.controls.yaw, Vector3(0.0f, 1.0f, 0.0f));

        // Switch between 1st and 3rd person
        if (input.keyPress[KEY_F])
            firstPerson = !firstPerson;

        // Check for loading / saving the scene
        if (input.keyPress[KEY_F5])
        {
            File saveFile(fileSystem.programDir + "Data/Scenes/CharacterDemo.xml", FILE_WRITE);
            sc.SaveXML(saveFile);
        }
        if (input.keyPress[KEY_F7])
        {
            File loadFile(fileSystem.programDir + "Data/Scenes/CharacterDemo.xml", FILE_READ);
            sc.LoadXML(loadFile);
            // After loading we have to reacquire the character scene node, as it has been recreated
            // Simply find by name as there's only one of them
            charNode = sc.GetChild("Jack", true);
            if (charNode is null)
                return;
        }
    }
}

