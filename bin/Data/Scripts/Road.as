#include "Scripts/RoadRect.as"
#include "Scripts/CreateModels.as"
#include "Scripts/Facade.as"

enum roadgen_types {
    ITEM_CITY,
    ITEM_CITY_MID_ROADL1,
    ITEM_CITY_MID_ROADL2,
    ITEM_CHUNK,
    ITEM_LANE,
    ITEM_ROAD,
    ITEM_SIDEWALK,
    ITEM_SPACE,
    ITEM_LOT,
    ITEM_BUILDING_SPACE,
    ITEM_BUILDING,
    ITEM_SQUARE,
};

const float simple_dist = 110.0;
class BuildingDetailed : ScriptObject {
    StaticModelGroup@ smg;
    float passed = 0.0;
    Vector3 last_cam_pos;
    void update_setting()
    {
        smg = node.GetComponent("StaticModelGroup");
        Vector3 pos1 = cam_node.worldPosition;
        if (pos1.Equals(last_cam_pos))
            return;
        pos1.y = 0;

        if (smg is null)
            Print("Bad StaticModelGroup");

        for (int i = 0; i < smg.numInstanceNodes; i++) {
            Vector3 pos2 = smg.instanceNodes[i].worldPosition;
            pos2.y = 0;
            float dist = (pos1 - pos2).length;
            bool t = smg.instanceNodes[i].enabled;
            if (!t && dist < simple_dist)
                smg.instanceNodes[i].enabled = true;
            else if (t && dist >= simple_dist)
                smg.instanceNodes[i].enabled = false;
        }
    }
    void Start()
    {
        passed = 0.0;
        last_cam_pos = cam_node.worldPosition;
        smg = node.GetComponent("StaticModelGroup");
        if (smg is null)
            Print("Bad StaticModelGroup");
        update_setting();
    }
    void FixedUpdate(float timeStep)
    {
        passed += timeStep;
        if (passed > 0.2) {
            update_setting();
            passed = 0.0;
        }
    }
};

class BuildingSimple : ScriptObject {
    StaticModelGroup@ smg;
    float passed = 0.0;
    Vector3 last_cam_pos;
    void update_setting()
    {
        Vector3 pos1 = cam_node.worldPosition;
        if (pos1.Equals(last_cam_pos))
            return;
        pos1.y = 0;

        for (int i = 0; i < smg.numInstanceNodes; i++) {
            Vector3 pos2 = smg.instanceNodes[i].worldPosition;
            pos2.y = 0;
            float dist = (pos1 - pos2).length;
            bool t = smg.instanceNodes[i].enabled;
            if (t && dist < simple_dist - 3.0)
                smg.instanceNodes[i].enabled = false;
            else if (!t && dist >= simple_dist - 3.0)
                smg.instanceNodes[i].enabled = true;
        }
    }
    void Start()
    {
        passed = 0.0;
        smg = node.GetComponent("StaticModelGroup");
        update_setting();
    }
    void FixedUpdate(float timeStep)
    {
        passed += timeStep;
        if (passed > 0.1) {
            update_setting();
            passed = 0.0;
        }
    }
};
class RoadChunk {
    RoadRect rect;
    int type;
    Vector2 size {
        get {
          return rect.size;
        }
    };
    String ToString()
    {
       String ret = "type: ";
       ret += String(type);
       ret += " rect: ";
       ret += rect.ToString();
       return ret;
    }
};

const float road_lane_width = 3.0;
const float road_lane_height = 0.05;
const float road_sidewalk_width = 1.5;
const float road_sidewalk_height = 0.1;

class BuildingStoreItem {
    StaticModelGroup@ model;
    Array<Dictionary@> windows;
    Vector2 size;
    float height;
    BuildingStoreItem(Node@ node)
    {
        model = node.CreateComponent("StaticModelGroup");
        node.CreateScriptObject(scriptFile, "BuildingDetailed");
        
    }
    BuildingStoreItem()
    {
    }
}

class RectStoreItem {
    StaticModelGroup@ model;
    Array<Node@> rects;
    Vector2 size;
    float height;
    int type;
    StaticModelGroup@ rect_group;
    RectStoreItem(Node@ node)
    {
        model = node.CreateComponent("StaticModelGroup");
    }
    RectStoreItem()
    {
    }
}

class BuildingStore {
    Array<BuildingStoreItem@> items;
    void add(BuildingStoreItem@ item)
    {
        items.Push(item);
    }
    BuildingStoreItem@ find(Vector2 size, float h)
    {
        Print("Find " + String(size.x) + " " + String(size.y) + " " + String(h));
        for (int i = 0; i < items.length; i++) {
            if (items[i].size.Equals(size) && items[i].height == h) {
                Print("Found");
                return items[i];
            }
        }
        Print("Not found");
        return BuildingStoreItem();
    }
}
class RectStore {
    Array<RectStoreItem@> items;
    void add(RectStoreItem@ item)
    {
        items.Push(item);
    }
    RectStoreItem@ find(Vector2 size, float h, int type)
    {
        Print("Find " + String(size.x) + " " + String(size.y) + " " + String(type));
        for (int i = 0; i < items.length; i++) {
            if (items[i].size.Equals(size) && items[i].type == type) {
                Print("Found");
                return items[i];
            }
        }
        Print("Not found");
        RectStoreItem @ret =  RectStoreItem();
        ret.size = size;
        ret.type = type;
        ret.height = h;
        return ret;
    }
}

class RoadGen : ScratchModel {
    BuildingStore@ buildings = BuildingStore();
    RectStore@ rects = RectStore();
    Node@ node = Node();
    StaticModel@ object;
    Array<String> type2str = {
        "city",
        "city_middle_road_lane1",
        "city_middle_road_lane2",
        "chunk",
        "lane",
        "road",
        "sidewalk",
        "space",
        "lot",
        "building_space",
        "building",
    };
    Array<RoadChunk> queue = {};
    Array<RoadChunk> result = {};
    float split_probability = 0.5;
    float max_chunk_size = 270.0;
    float min_chunk_size = (3.0 + 3.0) * 4.0 + 25.0;
    float max_building_size = (3.0 + 3.0) * 4 + 50.0;
    float min_building_size = (3.0 + 3.0) * 4 + 6.0;
    float sidewalk_width = 3.0;
    float lane_width = 6.0;
    Dictionary@ building_style = {
        {"window_distance", 1.2f}
    };
    void add(int t, RoadRect r)
    {
        RoadChunk v;
        v.type = t;
        v.rect = r;
        queue.Push(v);
    }
    void add_obj(Array<RoadChunk> @obj, int t, RoadRect r)
    {
        RoadChunk v;
        v.type = t;
        v.rect = r;
        obj.Push(v);
    }
    void add_result(int t, RoadRect r)
    {
        RoadChunk v;
        v.type = t;
        v.rect = r;
        result.Push(v);
    }
    RoadChunk fetch()
    {
        RoadChunk v = queue[0];
        queue.Erase(0);
        return v;
    }
    void print_queue()
    {
        Print("=== Begin queue item list ===");
        for (uint i = 0; i < queue.length; i++)
            Print("queue item " + String(i) + " " + type2str[queue[i].type]);
        Print("=== end queue item list ===");
    }
    void print_result()
    {
        Print("=== Begin result item list ===");
        for (uint i = 0; i < result.length; i++)
            Print("result item " + String(i) + " " + type2str[result[i].type] + " " + result[i].rect.ToString());
        Print("=== end result list ===");
    }
    Array<RoadRect> hsplit3(RoadRect rect, float l, float r)
    {
        Array<RoadRect> ret;
        Array<RoadRect> ret1 = rect.split2l(l);
        Array<RoadRect> ret2 = ret1[1].split2r(r);
        ret.Push(ret1[0]);
        ret.Push(ret2[0]);
        ret.Push(ret2[1]);
        return ret;
    }
    Array<RoadRect> vsplit3(RoadRect r, float t, float b)
    {
        Array<RoadRect> ret;
        Array<RoadRect> ret1 = r.split2t(t);
        Array<RoadRect> ret2 = ret1[1].split2b(b);
        ret.Push(ret1[0]);
        ret.Push(ret2[0]);
        ret.Push(ret2[1]);
        return ret;
    }
    void do_split4(int icenter_type, int iside_type, float d, RoadRect r)
    {
        Array<RoadRect> data = hsplit3(r, d, d);
        Array<RoadRect> data1 = vsplit3(data[0], d, d);
        Array<RoadRect> data2 = vsplit3(data[1], d, d);
        Array<RoadRect> data3 = vsplit3(data[2], d, d);
        // angle
        add(iside_type, data1[0]);
        add(iside_type, data1[1]);
        // angle
        add(iside_type, data1[2]);
        add(iside_type, data2[0]);
        add(iside_type, data2[2]);
        // angle
        add(iside_type, data3[0]);
        add(iside_type, data3[1]);
        // angle
        add(iside_type, data3[2]);
    }
    void do_split2(int typel, int typer, float d, RoadRect r)
    {
        Array<RoadRect> data = r.split2l(d);
        add(typel, data[0]);
        add(typer, data[1]);
    }

    Array<RoadChunk> split9(int icenter_type, int iside_type, float d, RoadChunk r)
    {
        Array<RoadChunk> ret;
        Array<RoadRect> data = hsplit3(r.rect, d, d);
        Array<RoadRect> data1 = vsplit3(data[0], d, d);
        Array<RoadRect> data2 = vsplit3(data[1], d, d);
        Array<RoadRect> data3 = vsplit3(data[2], d, d);
        // angle
        add_obj(ret, iside_type, data1[0]);
        add_obj(ret, iside_type, data1[1]);
        // angle
        add_obj(ret, iside_type, data1[2]);
        add_obj(ret, iside_type, data2[0]);
        add_obj(ret, icenter_type, data2[1]);
        add_obj(ret, iside_type, data2[2]);
        // angle
        add_obj(ret, iside_type, data3[0]);
        add_obj(ret, iside_type, data3[1]);
        // angle
        add_obj(ret, iside_type, data3[2]);
        return ret;
    }
    Array<RoadChunk> split2_random(int type1, int type2, RoadChunk c, float min_chunk)
    {
        Array<RoadChunk> ret;
        float rnd = Random();
        bool can_hsplit, can_vsplit, do_hsplit;
        can_hsplit = c.rect.can_hsplit(min_chunk, c.size.x / 2.0);
        can_vsplit = c.rect.can_hsplit(min_chunk, c.size.x / 2.0);
        if (can_hsplit && !can_vsplit)
            do_hsplit = true;
        else if (!can_hsplit && can_vsplit)
            do_hsplit = false;
        else if (c.size.x > c.size.y * 2.0)
            do_hsplit = true;
        else if (c.size.y > c.size.x * 2.0)
            do_hsplit = false;
        else if (rnd > 0.5)
            do_hsplit = true;
        else
            do_hsplit = false;
        if (do_hsplit) {
            Array<RoadRect> data = c.rect.split2l(c.size.x / 2.0);
            add_obj(ret, type1, data[0]);
            add_obj(ret, type2, data[1]);
        } else {
            Array<RoadRect> data = c.rect.split2t(c.size.y / 2.0);
            add_obj(ret, type1, data[0]);
            add_obj(ret, type2, data[1]);
        }
        return ret;
    }

    Array<RoadChunk> grow(RoadChunk c)
    {
        Array<RoadChunk> ret;
        switch(c.type) {
        case ITEM_CITY:
            ret = split9(ITEM_CITY_MID_ROADL1, ITEM_SIDEWALK, sidewalk_width, c);
            break;
        case ITEM_CITY_MID_ROADL1:
            ret = split9(ITEM_CITY_MID_ROADL2, ITEM_LANE, lane_width, c);
            break;
        case ITEM_CITY_MID_ROADL2:
            ret = split9(ITEM_CHUNK, ITEM_LANE, lane_width, c);
            break;
        case ITEM_CHUNK:
            if (c.rect.can_split(min_chunk_size, max_chunk_size))
                ret = split2_random(ITEM_CHUNK, ITEM_CHUNK, c, min_chunk_size);
            else if (c.rect.can_split(min_chunk_size, min_chunk_size)
                     && Random() >= split_probability)
                ret = split2_random(ITEM_CHUNK, ITEM_CHUNK, c, min_chunk_size);
            else
                ret = split9(ITEM_SPACE, ITEM_LANE, lane_width, c);
            break;
        case ITEM_SPACE:
            ret = split9(ITEM_LOT, ITEM_SIDEWALK, sidewalk_width, c);
            break;
        case ITEM_LOT:
            if (c.rect.size.x < min_building_size ||
                c.rect.size.y < min_building_size)
                add_obj(ret, ITEM_SQUARE, c.rect);
            else if (c.rect.can_split(min_building_size, max_building_size))
                ret = split2_random(ITEM_LOT, ITEM_LOT, c, min_building_size);
            else if (c.rect.can_split(min_building_size, min_building_size)
                     && Random() >= split_probability)
                ret = split2_random(ITEM_LOT, ITEM_LOT, c, min_building_size);
            else
                ret = split9(ITEM_BUILDING_SPACE, ITEM_SIDEWALK, sidewalk_width, c);
            break;
        case ITEM_BUILDING_SPACE:
            ret = split9(ITEM_BUILDING, ITEM_LANE, lane_width, c);
        }
        return ret;
    }
    Node@ render_rect(RoadChunk r, float h, Material@ mat)
    {
        Node@ ret = Node();
        RectStoreItem bsitem;
        bsitem = rects.find(r.size, h, r.type);
        if (bsitem.model is null) {
            bsitem = RectStoreItem(ret);
            bsitem.size = r.size;
            bsitem.height = h;
            bsitem.type = r.type;
        }
        if (bsitem.model.model is null) {
            RoadItem@ ritem = RoadItem(r.size.x, h, r.size.y, mat);
            StaticModel@ sm = ritem.node.GetComponent("StaticModel");
            bsitem.model.model = sm.model;
            bsitem.model.material = mat;
            bsitem.model.castShadows = true;
            bsitem.model.occluder = true;
            bsitem.model.occludee = true;
            bsitem.size = r.size;
            bsitem.height = h;
            rects.add(bsitem);
        } else
            Print("Using cache");
        ret.position = Vector3(r.rect.left + r.size.x / 2.0,
                                      0,
                                      r.rect.top + r.size.y / 2.0);
        Node@ rect_inst = ret.CreateChild("rect");
        bsitem.model.AddInstanceNode(rect_inst);

        return ret;
    }

   Node@ render_floor(RoadChunk r, float h, Material@ mat,
        StaticModelGroup@ window_group)
    {
        Node@ ret = Node();
        BuildingStoreItem bsitem;
        bsitem = buildings.find(r.size, h);
        if (bsitem.model is null) {
            bsitem = BuildingStoreItem(ret);
            bsitem.size = r.size;
            bsitem.height = h;
        }
        Matrix4 trans;
        Matrix4 window_rot = Matrix4();
        window_rot.SetRotation(Quaternion(0.0, 90.0, 0.0).rotationMatrix);
        DissectModel@ dm = DissectModel("Models/window/Models/window1.mdl", 0, window_rot);
        BoundingBox window_bb = dm.model.boundingBox;
        Array<Vector3> vs = dm.get_vertices();
        Dictionary meta = building_style;
        meta["window_height"] = window_bb.size.y - 0.02;
        meta["window_width"] = window_bb.size.z - 0.02;
        meta["min_floor_height"] = 2.5;
        meta["min_window_block_width"] = (float(meta["window_width"])
                              + float(meta["window_distance"])) * 3
                              + float(meta["window_distance"]);

        Array<Vector3> positions = {
            Vector3(0.0, 0.0, r.size.y / 2.0),
            Vector3(0.0, 0.0, -r.size.y / 2.0),
            Vector3(-r.size.x / 2.0, 0.0, 0.0),
            Vector3(r.size.x / 2.0, 0.0, 0.0)
        };
        Array<Vector3> sizes = {
            Vector3(r.size.x, h, 0.2),
            Vector3(r.size.x, h, 0.2),
            Vector3(r.size.y, h, 0.2),
            Vector3(r.size.y, h, 0.2)
        };
        Array<Quaternion> rotations = {
            Quaternion(0.0, 0.0, 0.0),
            Quaternion(0.0, 180.0f, 0.0),
            Quaternion(0.0, -90.0f, 0.0),
            Quaternion(0.0, 90.0f, 0.0)
        };

//        StaticModel@ object = ret.CreateComponent("StaticModel");
//        for (int i = 0; i < positions.length; i++) {
//            Matrix4 trans = Matrix4();
//            trans.SetRotation(rotations[i].rotationMatrix);
//            trans.SetTranslation(positions[i]);
//            Facade@ fac = Facade(sizes[i].x, sizes[i].y, sizes[i].z, meta);
//            fr.render(sizes[i].x, sizes[i].y, sizes[i].z, 0, 0.0, fac.result, Array<Vector3>(), trans);
//
//        }
//        fr.bbox = BoundingBox(Vector3(-r.size.x/2 - 0.01, -0.01,  -r.size.y/2.0 - 0.01), Vector3(r.size.x/2 + 0.01, h + 0.01, r.size.y/2.0 + 0.01));
//        fr.create();
//        object.model = fr.model;
//        object.material = mat;
//        object.castShadows = true;
//        object.occluder = true;
//        object.occludee = true;
        if (bsitem.model.model is null) {
            FacadeRender@ fr = FacadeRender();
            for (int i = 0; i < positions.length; i++) {
                Matrix4 btrans = Matrix4();
                btrans.SetRotation(rotations[i].rotationMatrix);
                btrans.SetTranslation(positions[i]);
                Facade@ fac = Facade(sizes[i].x, sizes[i].y, sizes[i].z, meta);
                fr.render(sizes[i].x, sizes[i].y, sizes[i].z, 0, 0.0f,
                    fac.result, Array<Vector3>(), btrans);
//                fr.render(sizes[i].x, sizes[i].y, sizes[i].z, 1, 3.0f,
//                    fac.result, Array<Vector3>(), btrans);
            }
            for (int j = 0; j < fr.window_pos.length; j++) {
                Dictionary@ win_node = Dictionary();
                win_node["position"] = fr.window_pos[j].pos;
                win_node["rotation"] = fr.window_pos[j].rot * Quaternion(0.0, -90.0, 0.0);
                bsitem.windows.Push(win_node);
            }
            fr.bbox = BoundingBox(Vector3(-r.size.x/2 - 0.01, -0.01,  -r.size.y/2.0 - 0.01), Vector3(r.size.x/2 + 0.01, h + 0.01, r.size.y/2.0 + 0.01));
            fr.create();
            bsitem.model.model = fr.model;
            bsitem.model.material = mat;
            bsitem.model.castShadows = true;
            bsitem.model.occluder = true;
            bsitem.model.occludee = true;
            bsitem.model.lodBias = 0.4;
            bsitem.size = r.size;
            bsitem.height = h;
            buildings.add(bsitem);
        } else
            Print("(building) Using cache\n");
        Print("Instancing building");
        Node@ building_inst = ret.CreateChild("building");
        bsitem.model.AddInstanceNode(building_inst);
        for (int j = 0; j < bsitem.windows.length; j++) {
            Node@ win_node = ret.CreateChild("window");
            win_node.position = Vector3(bsitem.windows[j]["position"]);
            win_node.rotation = Quaternion(bsitem.windows[j]["rotation"]);
            win_node.enabled = true;
            window_group.AddInstanceNode(win_node);
        }
        CollisionShape@ shape = ret.CreateComponent("CollisionShape");
        shape.SetTriangleMesh(bsitem.model.model, 0, Vector3(1.0, 1.0, 1.0));
        ret.position = Vector3(r.rect.left + r.size.x / 2.0,
                                      0,
                                      r.rect.top + r.size.y / 2.0);
        RigidBody@ body = ret.CreateComponent("RigidBody");
        body.collisionLayer = 2;
        body.collisionMask = 1;
        body.friction = 1;
        body.rollingFriction = 1;
        return ret;
    }
    
    Node@ build()
    {
        while(!queue.empty) {
            RoadChunk item = fetch();
            int item_type = item.type;
            RoadRect item_rect = item.rect;
            Array<RoadChunk>@ newchunks = grow(item);
            if (newchunks.length != 0) {
                for (int i = 0; i < newchunks.length; i++)
                    queue.Push(newchunks[i]);
            } else
                // finals
                add_result(item_type, item_rect);
/*
            if (can_split(item_rect)) {
                if (must_split(item_rect))
                    do_split(item_type, item_rect);
                else if (can_split(item_rect) && Random() > split_probability)
                    do_split(item_type, item_rect);
               else
                  add_result(ITEM_LOFT, item_rect);
	    }
*/
        }
        Node @node = Node();
        Material@ lane_material = Material();
        lane_material.SetTechnique(0, cache.GetResource("Technique", "Techniques/NoTexture.xml"));
        lane_material.shaderParameters["MatDiffColor"] =  Variant(Vector4(0.3, 0.3, 0.3, 1.0));
        Material@ sidewalk_material = Material();
        sidewalk_material.SetTechnique(0, cache.GetResource("Technique", "Techniques/NoTexture.xml"));
        sidewalk_material.shaderParameters["MatDiffColor"] = Variant(Vector4(0.4, 0.4, 0.4, 1.0));
        Material@ building_material = Material();
        building_material.SetTechnique(0, cache.GetResource("Technique", "Techniques/NoTexture.xml"));
        building_material.shaderParameters["MatDiffColor"] = Variant(Vector4(0.6, 0.4, 0.8, 1.0));
        Material@ window_material1 = cache.GetResource("Material", "Models/window/Materials/window-frame.xml");
        Material@ window_material2 = cache.GetResource("Material", "Models/window/Materials/glass.xml");
        Material@ window_material3 = cache.GetResource("Material", "Models/window/Materials/distant-window.xml");
        RigidBody @body = node.CreateComponent("RigidBody");
        body.collisionLayer = 2;
        body.collisionMask = 1;
        body.rollingFriction = 1;
        body.friction = 1;
        Node@ fake = node.CreateChild("fake-building");
        StaticModelGroup@ fake_smg = fake.CreateComponent("StaticModelGroup");
        fake_smg.model = cache.GetResource("Model", "Models/Box.mdl");
        fake_smg.material = building_material;
        fake.CreateScriptObject(scriptFile, "BuildingSimple");
        for (int i = 0; i < result.length; i++) {
            CollisionShape@ shape = node.CreateComponent("CollisionShape");
            Node @prect;
            StaticModelGroup@ sm;
            switch(result[i].type) {
            case ITEM_LANE:
                prect = render_rect(result[i], road_lane_height, lane_material);
                sm = rects.find(result[i].size, road_lane_height, result[i].type).model;
        	shape.SetTriangleMesh(sm.model, 0, Vector3(1.0, 1.0, 1.0), prect.position);

                node.AddChild(prect);
                break;
            case ITEM_SQUARE:
            case ITEM_SIDEWALK:
                prect = render_rect(result[i], road_sidewalk_height, sidewalk_material);
                node.AddChild(prect);
                node.position += Vector3(0.0, road_lane_height, 0.0);
                sm = rects.find(result[i].size, road_sidewalk_height, result[i].type).model;
        	shape.SetTriangleMesh(sm.model, 0, Vector3(1.0, 1.0, 1.0), prect.position);
                break;
            case ITEM_CHUNK:
            case ITEM_CITY_MID_ROADL1:
            case ITEM_LOT:
            case ITEM_BUILDING:
                {
                    int floor_number = 1 + RandomInt(18);
                    float building_height = 3.5 + 2.5 * floor_number;
                    float bottom_height = 0.5;
                    float floor_height = 2.7;
                    StaticModelGroup@ window_group = node.CreateComponent("StaticModelGroup");
//                    node.CreateScriptObject(scriptFile, "BuildingDetailed");
                    window_group.model = cache.GetResource("Model", "Models/window/Models/window1.mdl");
                    window_group.materials[0] = window_material1;
                    window_group.materials[1] = window_material2;
                    window_group.materials[2] = window_material3;
                    window_group.castShadows = true;
                    window_group.occludee = true;
                    window_group.lodBias = 0.4;
                    window_group.drawDistance = simple_dist - 10.0;
                    Node@ simple_building = node.CreateChild("simple-building");
                    simple_building.position = Vector3(result[i].rect.left + result[i].rect.size.x / 2.0,
                                               floor_height * floor_number / 2.0,
                                               result[i].rect.top + result[i].size.y / 2.0);
                    simple_building.scale = Vector3(result[i].rect.size.x, floor_height * floor_number, result[i].rect.size.y);
                    simple_building.enabled = false;
                    fake_smg.AddInstanceNode(simple_building);
        
                    Node@ b = render_floor(result[i], bottom_height,
                        building_material, window_group);
                    node.AddChild(b);
                    for (int j = 0; j < floor_number; j++) {
                        Print("Floor gen " + String(floor_height * j + bottom_height));
                        Node@ floor = node.CreateChild("floor");
                        Node@ flb = render_floor(result[i], floor_height,
                            building_material, window_group);
                        floor.AddChild(flb);
                        floor.position = Vector3(0.0, floor_height * j + bottom_height, 0.0);
                    }
                    node.position += Vector3(0.0, road_lane_height, 0.0);
                }
                break;
            }
        }
        node.position = Vector3(0, 0.2, 0);
        Print("=== BUILDINGS: " + String(buildings.items.length));
        for (int g = 0; g < buildings.items.length; g++) {
            Print("building: size.x: "
                    + String(buildings.items[g].size.x)
                    + " size.y: " + String(buildings.items[g].size.y)
                    + " height: " + String(buildings.items[g].height)
            );
        }
        return node;
    }
    
};

