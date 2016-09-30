#include "Scripts/Road.as"
#include "Scripts/CreateModels.as"
#include "Scripts/Controller.as"
#include "Scripts/Player.as"

Scene@ sc;
Node@ charNode;
Node@ cam_node;
Node@ minimap_cam_node = Node();

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
    else if (key == KEY_F2) {
        debugHud.ToggleAll();
        debug_render = !debug_render;
    }

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

void CreateCharacter()
{
        charNode = sc.CreateChild("Character");
        Character@ character = cast<Character>(charNode.CreateScriptObject(scriptFile, "Character"));
        character.Init();
}

Array<Node@> AI_cars;
void Start()
{
    in_vehicle = false;
    graphics.windowTitle = "Dungeon";
    RoadGen roads = RoadGen();
    engine.maxFps = 60.0;
    roads.add(ITEM_CITY, RoadRect(-200, -200, 200, 200));
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
    
    cam_node = Node();
    RenderPath@ rp = RenderPath();
    rp.Load(cache.GetResource("XMLFile", "RenderPaths/ForwardNoClear.xml"));
    Camera@ minimap_camera = minimap_cam_node.CreateComponent("Camera");
    minimap_camera.farClip = 600.0f;
    minimap_camera.orthographic = true;
    minimap_camera.zoom = 0.3;
    minimap_cam_node.position = Vector3(0.0, 200.0f, 0.0);
    minimap_cam_node.LookAt(Vector3(0.0, 0.0, 0.0));

    Camera@ camera = cam_node.CreateComponent("Camera");

    camera.farClip = 300.0f;
    renderer.numViewports = 2;
    renderer.viewports[0] = Viewport(sc, camera);
    renderer.viewports[1] = Viewport(sc, minimap_camera, IntRect(graphics.width * 2 / 3, 32, graphics.width - 32, graphics.height / 3));
    renderer.viewports[1].renderPath = rp;
    Node@ zoneNode = sc.CreateChild("Zone");
    Zone@ zone = zoneNode.CreateComponent("Zone");
    zone.boundingBox = BoundingBox(Vector3(-1000.0f,-10000.0, -1000.0f), Vector3(1000, 499, 1000));
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

    sc.AddChild(roads_node);

    // Subscribe to Update event for setting the character controls before physics simulation
    SubscribeToEvent("Update", "HandleUpdate");

    // Subscribe to PostUpdate event for updating the camera position after physics simulation
    SubscribeToEvent("PostUpdate", "HandlePostUpdate");
    SubscribeToEvent("PostRenderUpdate", "HandlePostRenderUpdate");

    // Character
    CreateCharacter();
    for (int i = 0; i < 40; i++) {
        Node@ ncar =  sc.CreateChild("Vehicle");
    	ncar.position = Vector3(Random(200.0), Random(50.0), Random(200.0)) - Vector3(100.0, 0.0, 100.0);
        ncar.rotation = Quaternion(0.0, Random(180.0), 0.0);

    	// Create the vehicle logic script object
    	Vehicle@ v = cast<Vehicle>(ncar.CreateScriptObject(scriptFile, "Vehicle"));
    	// Create the rendering and physics components
    	v.Init();
        AI_cars.Push(ncar);
        v.controls.Set(CTRL_BRAKE, true);
    }
}

bool debug_render = false;

void HandlePostRenderUpdate()
{
    if (debug_render) {
        renderer.DrawDebugGeometry(false);
        sc.physicsWorld.DrawDebugGeometry(true);
    }
}

void HandlePostUpdate(StringHash eventType, VariantMap& eventData)
{
    Node@ headNode = charNode.GetChild("head", true);
    minimap_cam_node.position = Vector3(headNode.worldPosition.x, minimap_cam_node.position.y, headNode.worldPosition.z);
    float timeStep = eventData["TimeStep"].GetFloat();
    CharacterCameraUpdate(sc, charNode, cam_node, timeStep);
}

void HandleUpdate(StringHash eventType, VariantMap& eventData)
{
    if (charNode is null)
        return;
    float timeStep = eventData["TimeStep"].GetFloat();
    handle_player_update(charNode, cam_node, timeStep);
    Character@ character = cast<Character>(charNode.scriptObject);
    if (character is null)
        return;
    if (ui.focusElement is null)
    {
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


/*
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
*/
}

