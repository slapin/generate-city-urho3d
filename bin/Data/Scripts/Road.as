#include "Scripts/RoadRect.as"
#include "Scripts/Createmodels.as"
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
class RoadGen : ScratchModel {
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
    float max_chunk_size = 520.0;
    float min_chunk_size = 30.0;
    float max_building_size = 120.0;
    float min_building_size = 30.0;
    float sidewalk_width = 3.0;
    float lane_width = 6.0;
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
    Array<RoadChunk> split2_random(int type1, int type2, RoadChunk c)
    {
        Array<RoadChunk> ret;
        float rnd = Random();
        if (c.size.x > c.size.y)
            rnd += 0.2;
        if (rnd > 0.5) {
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
                ret = split2_random(ITEM_CHUNK, ITEM_CHUNK, c);
            else if (c.rect.can_split(min_chunk_size, min_chunk_size)
                     && Random() >= split_probability)
                ret = split2_random(ITEM_CHUNK, ITEM_CHUNK, c);
            else
                ret = split9(ITEM_SPACE, ITEM_LANE, lane_width, c);
            break;
        case ITEM_SPACE:
            ret = split9(ITEM_LOT, ITEM_SIDEWALK, sidewalk_width, c);
            break;
        case ITEM_LOT:
            if (c.rect.can_split(min_building_size, max_building_size))
                ret = split2_random(ITEM_LOT, ITEM_LOT, c);
            else if (c.rect.can_split(min_building_size, min_building_size)
                     && Random() >= split_probability)
                ret = split2_random(ITEM_LOT, ITEM_LOT, c);
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
        RoadItem@ ritem = RoadItem(r.size.x, h, r.size.y, mat);
        ritem.node.position = Vector3(r.rect.left + r.size.x / 2.0,
                                      0,
                                      r.rect.top + r.size.y / 2.0);
        return ritem.node;
    }

    Node@ render_building(RoadChunk r, float h, Material@ mat)
    {
        Node@ ret = Node();
        Facade@ fac1 = Facade(r.size.x, h, 0.2, mat);
        ret.AddChild(fac1.node);
        fac1.node.position = Vector3(0.0, 0.0, r.size.y / 2.0);
        CollisionShape@ shape1 = ret.CreateComponent("CollisionShape");
        shape1.SetTriangleMesh(fac1.model, 0, Vector3(1.0, 1.0, 1.0), fac1.node.position);
        Facade@ fac2 = Facade(r.size.x, h, 0.2, mat);
        ret.AddChild(fac2.node);
        fac2.node.position = Vector3(0.0, 0.0, -r.size.y / 2.0);
        fac2.node.rotation = Quaternion(0.0, 180.0f, 0.0);
        CollisionShape@ shape2 = ret.CreateComponent("CollisionShape");
        shape2.SetTriangleMesh(fac2.model, 0, Vector3(1.0, 1.0, 1.0), fac2.node.position, fac2.node.rotation);
        Facade@ fac3 = Facade(r.size.y, h, 0.2, mat);
        ret.AddChild(fac3.node);
        fac3.node.position = Vector3(-r.size.x / 2.0, 0.0, 0.0);
        fac3.node.rotation = Quaternion(0.0, -90.0f, 0.0);
        CollisionShape@ shape3 = ret.CreateComponent("CollisionShape");
        shape3.SetTriangleMesh(fac3.model, 0, Vector3(1.0, 1.0, 1.0), fac3.node.position, fac3.node.rotation);
        Facade@ fac4 = Facade(r.size.y, h, 0.2, mat);
        fac4.node.position = Vector3(r.size.x / 2.0, 0.0, 0.0);
        fac4.node.rotation = Quaternion(0.0, 90.0f, 0.0);
        CollisionShape@ shape4 = ret.CreateComponent("CollisionShape");
        shape4.SetTriangleMesh(fac4.model, 0, Vector3(1.0, 1.0, 1.0), fac4.node.position, fac4.node.rotation);
        ret.AddChild(fac4.node);
        ret.position = Vector3(r.rect.left + r.size.x / 2.0,
                                      0,
                                      r.rect.top + r.size.y / 2.0);
        RigidBody@ body = ret.CreateComponent("RigidBody");
        body.collisionLayer = 2;
        body.collisionMask = 1;
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
        RigidBody @body = node.CreateComponent("RigidBody");
        body.collisionLayer = 2;
        body.collisionMask = 1;
        for (int i = 0; i < result.length; i++) {
            CollisionShape@ shape = node.CreateComponent("CollisionShape");
            Node @prect;
            StaticModel@ sm;
            switch(result[i].type) {
            case ITEM_LANE:
                prect = render_rect(result[i], road_lane_height, lane_material);
                sm = prect.GetComponent("StaticModel");
        	shape.SetTriangleMesh(sm.model, 0, Vector3(1.0, 1.0, 1.0), prect.position);

                node.AddChild(prect);
                break;
            case ITEM_SIDEWALK:
                prect = render_rect(result[i], road_sidewalk_height, sidewalk_material);
                node.AddChild(prect);
                node.position += Vector3(0.0, road_lane_height, 0.0);
                sm = prect.GetComponent("StaticModel");
        	shape.SetTriangleMesh(sm.model, 0, Vector3(1.0, 1.0, 1.0), prect.position);
                break;
            case ITEM_CHUNK:
            case ITEM_CITY_MID_ROADL1:
            case ITEM_LOT:
            case ITEM_BUILDING:
                prect = render_building(result[i], 4.5 + 55.6 * Random(), building_material);
                node.AddChild(prect);
                node.position += Vector3(0.0, road_lane_height, 0.0);
                break;
            }
        }
        node.position = Vector3(0, 0.2, 0);
        return node;
    }
    
};

