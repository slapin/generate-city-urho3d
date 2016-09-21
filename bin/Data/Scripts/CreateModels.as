class GeomData {
    float[] vertex_data;
    uint16[] index_data;
    int num_vertices()
    {
        return vertex_data.length / 6;
    }
    void add_vertex(Vector3 v)
    {
        vertex_data.Push(v.x);
        vertex_data.Push(v.y);
        vertex_data.Push(v.z);
        for (int i = 0; i < 3; i++)
            vertex_data.Push(0);
        uint16 idx = index_data.length;
        index_data.Push(idx);
    }
};

mixin class ScratchModel {
    Array<GeomData> geom;
    int current_geometry = 0;
    void add_geometry()
    {
        geom.Push(GeomData());
    }
    void add_vertex(Vector3 v)
    {
        geom[current_geometry].add_vertex(v);
    }
    Model@ model = Model();
    BoundingBox bbox;
    int total_num_verts = 0;
    void create()
    {
        total_num_verts = 0;
        VertexBuffer@ vb = VertexBuffer();
        IndexBuffer@ ib = IndexBuffer();
        vb.shadowed = true;
        ib.shadowed = true;
        Array<VertexElement> elements;
        elements.Push(VertexElement(TYPE_VECTOR3, SEM_POSITION));
        elements.Push(VertexElement(TYPE_VECTOR3, SEM_NORMAL));
        Print("Creating");

        for (uint g = 0; g < geom.length; g++) {
            float[]@ vertex_data = @geom[g].vertex_data;
            total_num_verts += geom[g].num_vertices();
            Print("Geometry: " + String(g) + " vertices: " + String(geom[g].num_vertices()));
            for (uint i = 0; i < geom[g].num_vertices(); i += 3) {
                Vector3 v1(vertex_data[6 * i], vertex_data[6 * i + 1], vertex_data[6 * i + 2]);
                Vector3 v2(vertex_data[6 * i + 6], vertex_data[6 * i + 7], vertex_data[6 * i + 8]);
                Vector3 v3(vertex_data[6 * i + 12], vertex_data[6 * i + 13], vertex_data[6 * i + 14]);

                Vector3 edge1 = v1 - v2;
                Vector3 edge2 = v1 - v3;
                Vector3 normal = edge1.CrossProduct(edge2).Normalized();
                vertex_data[6 * i + 3] = vertex_data[6 * i + 9] = vertex_data[6 * i + 15] = normal.x;
                vertex_data[6 * i + 4] = vertex_data[6 * i + 10] = vertex_data[6 * i + 16] = normal.y;
                vertex_data[6 * i + 5] = vertex_data[6 * i + 11] = vertex_data[6 * i + 17] = normal.z;
            }
        }
        vb.SetSize(total_num_verts, elements);
        VectorBuffer temp;
        for (uint g = 0; g < geom.length; g++) {
            for (uint i = 0; i < geom[g].vertex_data.length; ++i)
                temp.WriteFloat(geom[g].vertex_data[i]);
        }
        vb.SetData(temp);

        ib.SetSize(total_num_verts, false);
        temp.Clear();
        for (uint g = 0; g < geom.length; g++) {
            for (uint i = 0; i < geom[g].num_vertices(); ++i)
                temp.WriteUShort(geom[g].index_data[i]);
        }
        ib.SetData(temp);

        model.numGeometries = geom.length;
        int vertex_start = 0;
        int index_start = 0;
        for (uint g = 0; g < geom.length; g++) {
            Geometry@ gm = Geometry();
            gm.SetVertexBuffer(0, vb);
            gm.SetIndexBuffer(ib);
            gm.SetDrawRange(TRIANGLE_LIST, index_start,
                    geom[g].num_vertices(), vertex_start,
                    geom[g].num_vertices());
            model.SetGeometry(g, 0, gm);
            vertex_start += geom[g].num_vertices();
            index_start += geom[g].num_vertices();
        }
        model.boundingBox = bbox;
    }
    void add_vertex(Vector3 v)
    {
        vertex_data.Push(v.x);
        vertex_data.Push(v.y);
        vertex_data.Push(v.z);
        for (int i = 0; i < 3; i++)
            vertex_data.Push(0);
        uint16 idx = index_data.length;
        index_data.Push(idx);
    }
    void add_quad0(float w, float h, float d, Matrix4 trans = Matrix4())
    {
        add_vertex(trans * Vector3(-w/2, 0, d));
        add_vertex(trans * Vector3(-w/2, h, d));
        add_vertex(trans * Vector3(w/2, 0, d));
        add_vertex(trans * Vector3(-w/2, h, d));
        add_vertex(trans * Vector3(w/2, h, d));
        add_vertex(trans * Vector3(w/2, 0, d));
    }
    void add_quad1(float w, float h, float d, Matrix4 trans = Matrix4())
    {
        add_vertex(trans * Vector3(w/2, 0, d));
        add_vertex(trans * Vector3(-w/2, h, d));
        add_vertex(trans * Vector3(-w/2, 0, d));
        add_vertex(trans * Vector3(w/2, 0, d));
        add_vertex(trans * Vector3(w/2, h, d));
        add_vertex(trans * Vector3(-w/2, h, d));
    }
    void add_quad2(float w, float h, float d)
    {
        add_vertex(Vector3(d, 0, w/2));
        add_vertex(Vector3(d, h, -w/2));
        add_vertex(Vector3(d, 0, -w/2));
        add_vertex(Vector3(d, 0, w/2));
        add_vertex(Vector3(d, h, w/2));
        add_vertex(Vector3(d, h, -w/2));
    }
    void add_quad3(float w, float h, float d)
    {
        add_vertex(Vector3(d, 0, -w/2));
        add_vertex(Vector3(d, h, -w/2));
        add_vertex(Vector3(d, 0, w/2));
        add_vertex(Vector3(d, h, -w/2));
        add_vertex(Vector3(d, h, w/2));
        add_vertex(Vector3(d, 0, w/2));
    }
    void add_quad4(float w, float h, float d)
    {
        add_vertex(Vector3(-w/2, d, -h/2));
        add_vertex(Vector3(-w/2, d, h/2));
        add_vertex(Vector3(w/2, d, -h/2));
        add_vertex(Vector3(-w/2, d, h/2));
        add_vertex(Vector3(w/2, d, h/2));
        add_vertex(Vector3(w/2, d, -h/2));
    }
    void add_quad5(float w, float h, float d)
    {
        add_vertex(Vector3(w/2, d, -h/2));
        add_vertex(Vector3(-w/2, d, h/2));
        add_vertex(Vector3(-w/2, d, -h/2));
        add_vertex(Vector3(w/2, d, -h/2));
        add_vertex(Vector3(w/2, d, h/2));
        add_vertex(Vector3(-w/2, d, h/2));
    }
}

class RoadItem : ScratchModel {
    Node@ node = Node();
    StaticModel@ object;
//    float[] vertex_data = {
//    };
//    uint16[] index_data = {
//    };
//    float width = 0.0;
//    float height = 0.0;
//    float length = 0.0;
    RoadItem(float w, float h, float l, Material@ mat)
    {
        add_geometry();
        add_quad0(w, h, -l/2);
        add_quad1(w, h, l/2);
        add_quad2(l, h, -w/2);
        add_quad3(l, h, w/2);
        add_quad4(w, l, h);
        add_quad5(w, l, 0);
        bbox = BoundingBox(Vector3(-w/2 - 0.01, -0.01, -l/2 - 0.01), Vector3(w/2 + 0.01, h + 0.01, l/2.0 + 0.01));
        create();
        object = node.CreateComponent("StaticModel");
        object.model = model;
        object.castShadows = true;
        object.occluder = true;
        object.occludee = true;
        object.material = mat;
//        RigidBody@ body = node.CreateComponent("RigidBody");
//        body.collisionLayer = 2;
//        body.collisionMask = 1;
//        CollisionShape@ shape = node.CreateComponent("CollisionShape");
//        shape.SetTriangleMesh(model, 0);

    }
}


