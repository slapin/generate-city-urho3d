mixin class ScratchModel {
    float[] vertex_data;
    uint16[] index_data;
    BoundingBox bbox = BoundingBox(Vector3(0.0, 0.0, 0.0), Vector3(1.0, 1.0, 1.0));
    int num_vertices()
    {
        return vertex_data.length / 6;
    }
    Node@ node = Node();
    Model@ model = Model();
    StaticModel@ object;
    void create()
    {
        for (uint i = 0; i < num_vertices(); i += 3) {
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
        VertexBuffer@ vb = VertexBuffer();
        IndexBuffer@ ib = IndexBuffer();
        Geometry@ geom = Geometry();

        vb.shadowed = true;
        Array<VertexElement> elements;
        elements.Push(VertexElement(TYPE_VECTOR3, SEM_POSITION));
        elements.Push(VertexElement(TYPE_VECTOR3, SEM_NORMAL));
        vb.SetSize(num_vertices(), elements);
        VectorBuffer temp;
        for (uint i = 0; i < vertex_data.length; ++i)
            temp.WriteFloat(vertex_data[i]);
        vb.SetData(temp);

        ib.shadowed = true;
        ib.SetSize(num_vertices(), false);
        temp.Clear();
        for (uint i = 0; i < num_vertices(); ++i)
            temp.WriteUShort(index_data[i]);
        ib.SetData(temp);

        geom.SetVertexBuffer(0, vb);
        geom.SetIndexBuffer(ib);
        geom.SetDrawRange(TRIANGLE_LIST, 0, num_vertices());
        model.numGeometries = 1;
        model.SetGeometry(0, 0, geom);
        model.boundingBox = bbox;
        object = node.CreateComponent("StaticModel");
        object.model = model;
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
    void add_quad0(float w, float h, float d, Vector3 offt = Vector3(0.0, 0.0, 0.0))
    {
        add_vertex(Vector3(-w/2, 0, d) + offt);
        add_vertex(Vector3(-w/2, h, d) + offt);
        add_vertex(Vector3(w/2, 0, d) + offt);
        add_vertex(Vector3(-w/2, h, d) + offt);
        add_vertex(Vector3(w/2, h, d) + offt);
        add_vertex(Vector3(w/2, 0, d) + offt);
    }
    void add_quad1(float w, float h, float d, Vector3 offt = Vector3(0.0, 0.0, 0.0))
    {
        add_vertex(Vector3(w/2, 0, d) + offt);
        add_vertex(Vector3(-w/2, h, d) + offt);
        add_vertex(Vector3(-w/2, 0, d) + offt);
        add_vertex(Vector3(w/2, 0, d) + offt);
        add_vertex(Vector3(w/2, h, d) + offt);
        add_vertex(Vector3(-w/2, h, d) + offt);
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

class Triangle : ScratchModel {
    float[] vertex_data = {
        0, 0, 0,   0, 0, 0,
        0, 1, 0,   0, 0, 0,
        1, 0, 0,   0, 0, 0,
    };
    uint16[] index_data = {
        0, 1, 2
    };
    BoundingBox bbox = BoundingBox(Vector3(0.0, 0.0, 0.0), Vector3(1.0, 1.0, 0.0));
    Triangle()
    {
        create();
    }
}

class HTriangle : ScratchModel {
    float[] vertex_data = {
        0, 0, 0,   0, 0, 0,
        0, 0, 1,   0, 0, 0,
        1, 0, 0,   0, 0, 0,
    };
    uint16[] index_data = {
        0, 1, 2
    };
    BoundingBox bbox = BoundingBox(Vector3(0.0, 0.0, 0.0), Vector3(1.0, 1.0, 0.0));
    HTriangle()
    {
        create();
    }
}

class Quad : ScratchModel {
    float[] vertex_data = {
        0, 0, 0,   0, 0, 0,
        0, 1, 0,   0, 0, 0,
        1, 0, 0,   0, 0, 0,
        0, 1, 0,   0, 0, 0,
        1, 1, 0,   0, 0, 0,
        1, 0, 0,   0, 0, 0,
    };
    uint16[] index_data = {
        0, 1, 2, 3, 4, 5
    };
    BoundingBox bbox = BoundingBox(Vector3(0.0, 0.0, 0.0), Vector3(1.0, 1.0, 0.0));
    Quad()
    {
        create();
    }
}
class HQuad : ScratchModel {
    float[] vertex_data = {
        0, 0, 0,   0, 0, 0,
        0, 0, 1,   0, 0, 0,
        1, 0, 0,   0, 0, 0,
        0, 0, 1,   0, 0, 0,
        1, 0, 1,   0, 0, 0,
        1, 0, 0,   0, 0, 0,
    };
    uint16[] index_data = {
        0, 1, 2, 3, 4, 5
    };
    BoundingBox bbox = BoundingBox(Vector3(0.0, 0.0, 0.0), Vector3(1.0, 1.0, 0.0));
    HQuad()
    {
        create();
    }
}
class Cube : ScratchModel {
    float[] vertex_data = {
        // top
        0, 1, 0,   0, 0, 0,
        0, 1, 1,   0, 0, 0,
        1, 1, 0,   0, 0, 0,
        0, 1, 1,   0, 0, 0,
        1, 1, 1,   0, 0, 0,
        1, 1, 0,   0, 0, 0,

        // bottom
        1, 0, 0,   0, 0, 0,
        0, 0, 1,   0, 0, 0,
        0, 0, 0,   0, 0, 0,
        1, 0, 0,   0, 0, 0,
        1, 0, 1,   0, 0, 0,
        0, 0, 1,   0, 0, 0,

        // front
        0, 0, 0,   0, 0, 0,
        0, 1, 0,   0, 0, 0,
        1, 0, 0,   0, 0, 0,
        0, 1, 0,   0, 0, 0,
        1, 1, 0,   0, 0, 0,
        1, 0, 0,   0, 0, 0,

        // back
        1, 0, 1,   0, 0, 0,
        0, 1, 1,   0, 0, 0,
        0, 0, 1,   0, 0, 0,
        1, 0, 1,   0, 0, 0,
        1, 1, 1,   0, 0, 0,
        0, 1, 1,   0, 0, 0,
       // left
        0, 0, 1,   0, 0, 0,
        0, 1, 0,   0, 0, 0,
        0, 0, 0,   0, 0, 0,
        0, 0, 1,   0, 0, 0,
        0, 1, 1,   0, 0, 0,
        0, 1, 0,   0, 0, 0,
       // right
        1, 0, 0,   0, 0, 0,
        1, 1, 0,   0, 0, 0,
        1, 0, 1,   0, 0, 0,
        1, 1, 0,   0, 0, 0,
        1, 1, 1,   0, 0, 0,
        1, 0, 1,   0, 0, 0,
    };
    uint16[] index_data = {
        0, 1, 2, 3, 4, 5,
        6, 7, 8, 9, 10, 11,
        12, 13, 14, 15, 16, 17,
        18, 19, 20, 21, 22, 23,
        24, 25, 26, 27, 28, 29,
        30, 31, 32, 33, 34, 35
    };
    BoundingBox bbox = BoundingBox(Vector3(0.0, 0.0, 0.0), Vector3(1.0, 1.0, 0.0));
    Cube()
    {
        create();
    }
}

class RoadItem : ScratchModel {
//    float[] vertex_data = {
//    };
//    uint16[] index_data = {
//    };
//    float width = 0.0;
//    float height = 0.0;
//    float length = 0.0;
    RoadItem(float w, float h, float l, Material@ mat)
    {
        add_quad0(w, h, -l/2);
        add_quad1(w, h, l/2);
        add_quad2(l, h, -w/2);
        add_quad3(l, h, w/2);
        add_quad4(w, l, h);
        add_quad5(w, l, 0);
        bbox = BoundingBox(Vector3(-w/2 - 0.01, -0.01, -l/2 - 0.01), Vector3(w/2 + 0.01, h + 0.01, l/2.0 + 0.01));
        create();
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


