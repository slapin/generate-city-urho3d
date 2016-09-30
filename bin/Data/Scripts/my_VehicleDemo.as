// Vehicle example.
// This sample demonstrates:
//     - Creating a heightmap terrain with collision
//     - Constructing a physical vehicle with rigid bodies for the hull and the wheels, joined with constraints
//     - Saving and loading the variables of a script object, including node & component references

#include "Scripts/Sample.as"
#include "Scripts/Controller.as"
#include "Scripts/Player.as"


Node@ vehicleNode;

void Start()
{
    in_vehicle = true;
    // Execute the common startup for samples
    SampleStart();

    // Create static scene content
    CreateScene();

    // Create the controllable vehicle
    CreateVehicle();

    // Create the UI content
    CreateInstructions();

    // Set the mouse mode to use in the sample
    SampleInitMouseMode(MM_RELATIVE);

    // Subscribe to necessary events
    SubscribeToEvents();
}

void CreateScene()
{
    scene_ = Scene();

    // Create scene subsystem components
    scene_.CreateComponent("Octree");
    scene_.CreateComponent("PhysicsWorld");
    scene_.CreateComponent("DebugRenderer");

    // Create camera and define viewport. Camera does not necessarily have to belong to the scene
    cameraNode = Node();
    Camera@ camera = cameraNode.CreateComponent("Camera");
    camera.farClip = 500.0f;
    renderer.viewports[0] = Viewport(scene_, camera);

    // Create static scene content. First create a zone for ambient lighting and fog control
    Node@ zoneNode = scene_.CreateChild("Zone");
    Zone@ zone = zoneNode.CreateComponent("Zone");
    zone.ambientColor = Color(0.15f, 0.15f, 0.15f);
    zone.fogColor = Color(0.5f, 0.5f, 0.7f);
    zone.fogStart = 300.0f;
    zone.fogEnd = 500.0f;
    zone.boundingBox = BoundingBox(-2000.0f, 2000.0f);

    // Create a directional light to the world. Enable cascaded shadows on it
    Node@ lightNode = scene_.CreateChild("DirectionalLight");
    lightNode.direction = Vector3(0.3f, -0.5f, 0.425f);
    Light@ light = lightNode.CreateComponent("Light");
    light.lightType = LIGHT_DIRECTIONAL;
    light.castShadows = true;
    light.shadowBias = BiasParameters(0.00025f, 0.5f);
    light.shadowCascade = CascadeParameters(10.0f, 50.0f, 200.0f, 0.0f, 0.8f);
    light.specularIntensity = 0.5f;

    // Create heightmap terrain with collision
    Node@ terrainNode = scene_.CreateChild("Terrain");
    terrainNode.position = Vector3(0.0f, 0.0f, 0.0f);
    Terrain@ terrain = terrainNode.CreateComponent("Terrain");
    terrain.patchSize = 16;
    terrain.spacing = Vector3(2.0f, 0.6f, 2.0f); // Spacing between vertices and vertical resolution of the height map
    terrain.smoothing = true;
    terrain.heightMap = cache.GetResource("Image", "Textures/HeightMap.png");
    terrain.material = cache.GetResource("Material", "Materials/Terrain.xml");
    // The terrain consists of large triangles, which fits well for occlusion rendering, as a hill can occlude all
    // terrain patches and other objects behind it
    terrain.occluder = true;

    RigidBody@ body = terrainNode.CreateComponent("RigidBody");
    body.collisionLayer = 2; // Use layer bitmask 2 for static geometry
    CollisionShape@ shape = terrainNode.CreateComponent("CollisionShape");
    shape.SetTerrain();
    body.rollingFriction = 1;
    body.friction = 1;

    // Create 1000 mushrooms in the terrain. Always face outward along the terrain normal
    const uint NUM_MUSHROOMS = 1500;
    for (uint i = 0; i < NUM_MUSHROOMS; ++i)
    {
        Node@ objectNode = scene_.CreateChild("Mushroom");
        Vector3 position(Random(2000.0f) - 1000.0f, 0.0f, Random(2000.0f) - 1000.0f);
        position.y = terrain.GetHeight(position) - 0.1f;
        objectNode.position = position;
        // Create a rotation quaternion from up vector to terrain normal
        objectNode.rotation = Quaternion(Vector3(0.0f, 1.0f, 0.0), terrain.GetNormal(position));
        objectNode.SetScale(3.0f);
        StaticModel@ object = objectNode.CreateComponent("StaticModel");
        object.model = cache.GetResource("Model", "Models/Box.mdl");
        object.material = cache.GetResource("Material", "Materials/Stone.xml");
        object.castShadows = true;

        RigidBody@ body = objectNode.CreateComponent("RigidBody");
        body.collisionLayer = 2;
        CollisionShape@ shape = objectNode.CreateComponent("CollisionShape");
        shape.SetTriangleMesh(object.model, 0);
    }
}

Array<Node@> AI_cars;
void CreateVehicle()
{
    vehicleNode = scene_.CreateChild("Vehicle");
    vehicleNode.position = Vector3(0.0f, 5.0f, 0.0f);

    // Create the vehicle logic script object
    Vehicle@ vehicle = cast<Vehicle>(vehicleNode.CreateScriptObject(scriptFile, "Vehicle"));
    // Create the rendering and physics components
    vehicle.Init();
    for (int i = 0; i < 20; i++) {
        Node@ ncar =  scene_.CreateChild("Vehicle");
    	ncar.position = Vector3(Random(400.0), Random(50.0), Random(400.0)) - Vector3(200.0, -210.0, -200.0);

    	// Create the vehicle logic script object
    	Vehicle@ v = cast<Vehicle>(ncar.CreateScriptObject(scriptFile, "Vehicle"));
    	// Create the rendering and physics components
    	v.Init();
        AI_cars.Push(ncar);
    }
}
void UpdateAIVehicles(float timeStep)
{
    Vector3 target = vehicleNode.position;
    
    for (int i = 0; i < AI_cars.length; i++) {
        Vector3 trans =  AI_cars[i].transform.Inverse() * target;
        
        Vehicle@ v = cast<Vehicle>(AI_cars[i].scriptObject);
        float current_steer = v.steering;
        float new_steer = trans.x / trans.length;
        float speed = v.hullBody.linearVelocity.length / timeStep;
        if (current_steer < new_steer + 0.1) {
                 v.controls.Set(CTRL_RIGHT, true);
                 v.controls.Set(CTRL_LEFT, false);
        } else if (current_steer > new_steer - 0.1) {
                 v.controls.Set(CTRL_LEFT, true);
                 v.controls.Set(CTRL_RIGHT, false);
        }
        else {
                 v.controls.Set(CTRL_LEFT, false);
                 v.controls.Set(CTRL_RIGHT, false);
        }
        if (new_steer > 0.3 || new_steer < -0.3) {
            if (speed > 240)
                v.controls.Set(CTRL_FORWARD, false);
            else
                v.controls.Set(CTRL_FORWARD, true);
        } else if (new_steer <= 0.3 && new_steer >= -0.3) {
            if (speed > 1640)
                v.controls.Set(CTRL_FORWARD, false);
            else
                v.controls.Set(CTRL_FORWARD, true);
        }
    }
}

void CreateInstructions()
{
    // Construct new Text object, set string to display and font to use
    Text@ instructionText = ui.root.CreateChild("Text");
    instructionText.text = "Use WASD keys to drive, mouse/touch to rotate camera\n"
        "F5 to save scene, F7 to load";
    instructionText.SetFont(cache.GetResource("Font", "Fonts/Anonymous Pro.ttf"), 15);
    // The text has multiple rows. Center them in relation to each other
    instructionText.textAlignment = HA_CENTER;

    // Position the text relative to the screen center
    instructionText.horizontalAlignment = HA_CENTER;
    instructionText.verticalAlignment = VA_CENTER;
    instructionText.SetPosition(0, ui.root.height / 4);
}

void SubscribeToEvents()
{
    // Subscribe to Update event for setting the vehicle controls before physics simulation
    SubscribeToEvent("Update", "HandleUpdate");

    // Subscribe to PostUpdate event for updating the camera position after physics simulation
    SubscribeToEvent("PostUpdate", "HandlePostUpdate");

    // Unsubscribe the SceneUpdate event from base class as the camera node is being controlled in HandlePostUpdate() in this sample
    UnsubscribeFromEvent("SceneUpdate");

    SubscribeToEvent("PostRenderUpdate", "HandlePostRenderUpdate");
}

void HandleUpdate(StringHash eventType, VariantMap& eventData)
{
    float timeStep = eventData["TimeStep"].GetFloat();
    if (vehicleNode is null)
        return;

    handle_player_update(vehicleNode, cameraNode, timeStep);

//    Vehicle@ vehicle = cast<Vehicle>(vehicleNode.scriptObject);
//    if (vehicle is null)
//        return;

    // Get movement controls and assign them to the vehicle component. If UI has a focused element, clear controls
    if (ui.focusElement is null)
    {
        UpdateAIVehicles(timeStep);
/*
        // Check for loading / saving the scene
        if (input.keyPress[KEY_F5])
        {
            File saveFile(fileSystem.programDir + "Data/Scenes/VehicleDemo.xml", FILE_WRITE);
            scene_.SaveXML(saveFile);
        }
        if (input.keyPress[KEY_F7])
        {
            File loadFile(fileSystem.programDir + "Data/Scenes/VehicleDemo.xml", FILE_READ);
            scene_.LoadXML(loadFile);
            // After loading we have to reacquire the vehicle scene node, as it has been recreated
            // Simply find by name as there's only one of them
            vehicleNode = scene_.GetChild("Vehicle", true);
        }
*/
    }
}

void HandlePostUpdate(StringHash eventType, VariantMap& eventData)
{
    float timeStep = eventData["TimeStep"].GetFloat();
    VehicleCameraUpdate(scene_, vehicleNode, cameraNode, timeStep);

}

// Create XML patch instructions for screen joystick layout specific to this sample app
String patchInstructions = "";
