using FactCheck
using Base.Test

import OpenCL 
cl = OpenCL

macro throws_pred(ex) FactCheck.throws_pred(ex) end 

# define usable platforms as those that contain
# all working devices
function available_platforms()
    usable_platforms = {}
    for platform in cl.platforms()
        usable = true
        for device in cl.devices(platform)
            try
                cl.Context(device)
            catch err
                usable = false
            end
        end
        if usable
            push!(usable_platforms, platform)
        end
    end
    return usable_platforms
end


facts("OpenCL.Platform") do 
    
    context("Platform Info") do
        @fact length(cl.platforms()) => cl.num_platforms()
        for p in cl.platforms()
            @fact p != nothing => true
            @fact pointer(p) != C_NULL => true
            for k in [:profile, :version, :name, :vendor, :extensions]
                @fact p[k] == cl.info(p, k) => true
            end
         end
     end
     
     context("Platform Equality") do 
        platform       = cl.platforms()[1]
        platform_copy  = cl.platforms()[1]
        
        @fact pointer(platform) => pointer(platform_copy) 
        @fact hash(platform) => hash(platform_copy)
        @fact isequal(platform, platform) => true
        
        if length(cl.platforms()) > 1
            for p in cl.platforms()[2:end]
                @fact pointer(platform) == pointer(p) => false
                @fact hash(platform) == hash(p) => false
                @fact isequal(platform, p) => false
            end
        end
    end
end

facts("OpenCL.Device") do 
    
    context("Device Type") do
        for p in cl.platforms()
            for (t, k) in zip((cl.CL_DEVICE_TYPE_GPU, cl.CL_DEVICE_TYPE_CPU, 
                               cl.CL_DEVICE_TYPE_ACCELERATOR, cl.CL_DEVICE_TYPE_ALL), 
                              (:gpu, :cpu, :accelerator, :all))
                
                #for (dk, dt) in zip(cl.devices(p, k), cl.devices(p, t))
                #    @fact dk == dt => true
                #end
                #devices = cl.devices(p, k)
                #for d in devices
                #    @fact d[:device_type] == t => true
                #end
            end
        end
    end

    context("Device Equality") do
        for platform in cl.platforms()
            devices = cl.devices(platform)
            if length(devices) > 1
                test_dev = devices[1]
                for dev in devices[2:end]
                   @fact pointer(dev) != pointer(test_dev) => true
                   @fact hash(dev) != hash(test_dev) => true
                   @fact isequal(dev, test_dev) => false
               end
           end
       end

    end

    context("Device Info") do 
        device_info_keys = Symbol[
                :driver_version,
                :version,
                :extensions,
                :platform,
                :name,
                :device_type,
                :has_image_support,
                :queue_properties,
                :has_queue_out_of_order_exec,
                :has_queue_profiling,
                :has_native_kernel,
                :vendor_id,
                :max_compute_units,
                :max_work_item_sizes,
                :max_clock_frequency,
                :address_bits,
                :max_read_image_args,
                :max_write_image_args,
                :global_mem_size,
                :max_mem_alloc_size,
                :max_const_buffer_size,
                :local_mem_size,
                :has_local_mem,
                :host_unified_memory,
                :available,
                :compiler_available,
                :max_workgroup_size,
                :max_parameter_size,
                :profiling_timer_resolution,
                :max_image2d_shape,
                :max_image3d_shape,
            ]
        for p in cl.platforms()
            @fact isa(p, cl.Platform) => true
            @fact @throws_pred(p[:zjdlkf]) => (true, "error")
            for d in cl.devices(p)
                @fact isa(d, cl.Device) => true
                @fact @throws_pred(d[:zjdlkf]) => (true, "error")
                for k in device_info_keys
                    @fact @throws_pred(d[k]) => (false, "no error")
                    @fact d[k] => cl.info(d, k)
                    if k == :extensions
                        @fact isa(d[k], Vector{String}) => true 
                    elseif k == :platform
                        @fact d[k] => p 
                    elseif k == :max_work_item_sizes
                        @fact length(d[k]) => 3
                    elseif k == :max_image2d_shape
                        @fact length(d[k]) => 2
                    elseif k == :max_image3d_shape
                        @fact length(d[k]) => 3
                    end
                end
            end
        end
    end
end

facts("OpenCL.Context") do

    context("OpenCL.Context device constructor") do
        @fact @throws_pred(cl.Context([])) => (true, "error")
        for platform in cl.platforms()
            for device in cl.devices(platform)
                @fact @throws_pred(cl.Context(device)) => (false, "no error")
            end
        end
    end

    context("OpenCL.Context device_type constructor") do
        for platform in cl.platforms()
            try
                cl.Context(cl.CL_DEVICE_TYPE_CPU)
            catch err
                @fact typeof(err) => cl.CLError
                @fact err.desc => :CL_INVALID_PLATFORM
            end
            properties = [(cl.CL_CONTEXT_PLATFORM, platform)]
            @fact @throws_pred(cl.Context(cl.CL_DEVICE_TYPE_CPU,
                               properties=properties)) => (false, "no error") 
            ctx = cl.Context(cl.CL_DEVICE_TYPE_CPU, properties=properties)
            @fact isempty(cl.properties(ctx)) => false
            test_properties = cl.properties(ctx)
            platform_in_properties = false 
            for (t, v) in test_properties
                if t == cl.CL_CONTEXT_PLATFORM
                    @fact v[:name] => platform[:name]
                    @fact v == platform => true
                    platform_in_properties = true
                    break
                end
            end
            @fact platform_in_properties => true 
            @fact @throws_pred(cl.Context(:cpu, properties=properties)) => (false, "no error")
            try
                ctx2 = cl.Context(cl.CL_DEVICE_TYPE_ACCELERATOR,
                                  properties=properties)
            catch err
                @fact typeof(err) => cl.CLError
                @fact err.desc => :CL_DEVICE_NOT_FOUND
            end
        end
    end

    context("OpenCL.Context create_some_context") do
        @fact @throws_pred(cl.create_some_context()) => (false, "no error")
        @fact typeof(cl.create_some_context()) => cl.Context
    end
end

facts("OpenCL.CmdQueue") do 
    context("OpenCL.CmdQueue device constructor") do
        @fact @throws_pred(cl.CmdQueue(nothing, nothing)) => (true, "error")
        for platform in cl.platforms()
            for device in cl.devices(platform)
                ctx = cl.Context(device)
                @fact @throws_pred(cl.CmdQueue(ctx)) => (false, "no error")
                @fact @throws_pred(cl.CmdQueue(ctx, device)) => (false, "no error")
            end
        end
    end

    context("OpenCL.CmdQueue info") do
        for platform in cl.platforms()
            for device in cl.devices(platform)
                ctx = cl.Context(device)
                for q in (cl.CmdQueue(ctx), cl.CmdQueue(ctx, device))
                    @fact q[:context] => ctx
                    @fact q[:device] => device
                    @fact q[:reference_count] > 0 => true
                    @fact typeof(q[:properties]) => cl.CL_command_queue_properties
                end
            end
        end
    end
end

facts("OpenCL.Event") do
    context("OpenCL.Event status") do
        #TODO: check if this is version 1.2 or greater..
        ctx = cl.create_some_context()
        evt = cl.UserEvent(ctx)
        evt[:status]
        @fact evt[:status] => cl.CL_SUBMITTED
        cl.complete(evt)
        @fact evt[:status] => cl.CL_COMPLETE
    end

    context("OpenCL.Event wait") do
        ctx = cl.create_some_context()
        # create user event
        usr_evt = cl.UserEvent(ctx)
        q = cl.CmdQueue(ctx)
        cl.enqueue_wait_for_events(q, usr_evt)

        # create marker event
        mkr_evt = cl.enqueue_marker(q)
        
        @fact usr_evt[:status] => cl.CL_SUBMITTED
        @fact mkr_evt[:status] => cl.CL_QUEUED

        cl.complete(usr_evt)
        @fact usr_evt[:status] => cl.CL_COMPLETE

        cl.wait(mkr_evt)
        @fact mkr_evt[:status] => cl.CL_COMPLETE
    end

    context("OpenCL.Event callback") do
        callback_called = false

        function test_callback(evt, status) 
            callback_called = true
            println("Test Callback") 
        end
        
        #Intel platform works, AMD does not...
        ctx = cl.Context(cl.devices()[end])
        #ctx = cl.create_some_context()
        usr_evt = cl.UserEvent(ctx)
        queue = cl.CmdQueue(ctx)
        
        cl.enqueue_wait_for_events(queue, usr_evt)
        
        mkr_evt = cl.enqueue_marker(queue)
        cl.add_callback(mkr_evt, test_callback)

        @fact usr_evt[:status] => cl.CL_SUBMITTED
        @fact mkr_evt[:status] => cl.CL_QUEUED
        @fact callback_called => false
        
        cl.complete(usr_evt)
        @fact usr_evt[:status] => cl.CL_COMPLETE
        
        cl.wait(mkr_evt)
        @fact mkr_evt[:status] => cl.CL_COMPLETE
        @fact callback_called => true
    end       
end

facts("OpenCL.Buffer") do

    function create_test_buffer()
        ctx = cl.create_some_context()
        queue = cl.CmdQueue(ctx)
        testarray = zeros(Float32, 1000)
        buf = cl.Buffer(ctx, cl.CL_MEM_COPY_HOST_PTR | cl.CL_MEM_READ_WRITE,
                        hostbuf=testarray)
        return (queue, buf, testarray)
    end

    context("OpenCL.Buffer constructors") do
        ctx = cl.create_some_context()
        testarray = zeros(Float32, 1000)

        @fact @throws_pred(cl.Buffer(ctx, cl.CL_MEM_ALLOC_HOST_PTR | cl.CL_MEM_READ_ONLY,
                                     sizeof(testarray))) => (false, "no error")
        
        @fact @throws_pred(cl.Buffer(ctx, cl.CL_MEM_ALLOC_HOST_PTR | cl.CL_MEM_WRITE_ONLY,
                                     sizeof(testarray))) => (false, "no error")
         
        @fact @throws_pred(cl.Buffer(ctx, cl.CL_MEM_ALLOC_HOST_PTR | cl.CL_MEM_READ_WRITE,
                                     sizeof(testarray))) => (false, "no error")

        buf = cl.Buffer(ctx, cl.CL_MEM_ALLOC_HOST_PTR | cl.CL_MEM_READ_WRITE, sizeof(testarray))
        @fact buf.size => sizeof(testarray)

        @fact @throws_pred(cl.Buffer(ctx, cl.CL_MEM_COPY_HOST_PTR | cl.CL_MEM_READ_ONLY, 
                                     hostbuf=testarray)) => (false, "no error")

        @fact @throws_pred(cl.Buffer(ctx, cl.CL_MEM_COPY_HOST_PTR | cl.CL_MEM_WRITE_ONLY,
                                     hostbuf=testarray)) => (false, "no error")

        @fact @throws_pred(cl.Buffer(ctx, cl.CL_MEM_COPY_HOST_PTR | cl.CL_MEM_READ_WRITE,
                                     hostbuf=testarray)) => (false, "no error")
          
        buf = cl.Buffer(ctx, cl.CL_MEM_COPY_HOST_PTR | cl.CL_MEM_READ_WRITE, hostbuf=testarray)
        @fact buf.size => sizeof(testarray)
        
        @fact @throws_pred(cl.Buffer(ctx, cl.CL_MEM_USE_HOST_PTR | cl.CL_MEM_READ_ONLY,
                                     hostbuf=testarray)) => (false, "no error")

        @fact @throws_pred(cl.Buffer(ctx, cl.CL_MEM_USE_HOST_PTR | cl.CL_MEM_WRITE_ONLY,
                                     hostbuf=testarray)) => (false, "no error")

        @fact @throws_pred(cl.Buffer(ctx, cl.CL_MEM_USE_HOST_PTR | cl.CL_MEM_READ_WRITE,
                                     hostbuf=testarray)) => (false, "no error")

        buf = cl.Buffer(ctx, cl.CL_MEM_USE_HOST_PTR | cl.CL_MEM_READ_WRITE, hostbuf=testarray)
        @fact buf.size => sizeof(testarray)
       
        # invalid buffer size should throw error
        @fact @throws_pred(cl.Buffer(ctx, cl.CL_MEM_ALLOC_HOST_PTR, +0)) => (true, "error")
        @fact @throws_pred(cl.Buffer(ctx, cl.CL_MEM_ALLOC_HOST_PTR, -1)) => (true, "error")

        # invalid flag combinations should throw error
        @fact @throws_pred(cl.Buffer(ctx, cl.CL_MEM_USE_HOST_PTR | cl.CL_MEM_ALLOC_HOST_PTR,
                                     hostbuf=testarray)) => (true, "error")

        # invalid host pointer should throw error
        @fact @throws_pred(cl.Buffer(ctx, cl.CL_MEM_COPY_HOST_PTR,
                                     hostbuf=C_NULL)) => (true, "error")
        
        @fact @throws_pred(cl.Buffer(ctx, cl.CL_MEM_USE_HOST_PTR,
                                     hostbuf=C_NULL)) => (true, "error")
     end

     context("OpenCL.Buffer fill") do
        queue, buf, testarray = create_test_buffer()
        
        @fact buf.size == sizeof(testarray) => true
        cl.fill!(queue, buf, float32(1.0))
        readback = cl.read(queue, buf)
        @fact all(x -> x == 1.0, readback) => true
        @fact all(x -> x == 0.0, testarray) => true
    end

    context("OpenCL.Buffer write!") do
        queue, buf, testarray = create_test_buffer()
        
        @fact buf.size == sizeof(testarray) => true
        cl.write!(queue, buf, ones(Float32, length(testarray)))
        readback = cl.read(queue, buf)
        @fact all(x -> x == 1.0, readback) => true
    end

    context("OpenCL.Buffer empty") do
        ctx = cl.create_some_context()
        testarray = zeros(Float32, 1000)
        buf = cl.Buffer(ctx, cl.CL_MEM_COPY_HOST_PTR | cl.CL_MEM_READ_WRITE,
                        hostbuf=testarray)

        @fact @throws_pred(cl.empty(Float32, ctx, -1)) => (true, "error") 
        empty_buf = cl.empty(Float32, ctx, 1000)
        @fact empty_buf.size => sizeof(testarray)
        @fact empty_buf.size => buf.size
       
        dims = (100, 100)
        testarray = zeros(Float32, dims)
        empty_buf = cl.empty(Float32, ctx, dims)
        @fact empty_buf.size => sizeof(testarray)
    end
end

facts("OpenCL.Program") do 
    
    test_source = "
    __kernel void sum(__global const float *a,
                      __global const float *b, 
                      __global float *c)
    {
      uint gid = get_global_id(0);
      c[gid] = a[gid] + b[gid];
    }
    "

    function create_test_program()
        ctx = cl.create_some_context()
        cl.Program(ctx, source=test_source)
    end

    context("OpenCL.Program source constructor") do
        ctx = cl.create_some_context()
        @fact @throws_pred(cl.Program(ctx, source=test_source)) => (false, "no error")
    end
    
    #TODO: build programs with binaries
    
    context("OpenCL.Program build") do 
        prg = create_test_program()
        @fact @throws_pred(cl.build!(prg)) => (false, "no error")
        cl.build!(prg)
    end

    context("OpenCL.Program source code") do
        prg = create_test_program()
        println(cl.source_code(prg))
    end

    context("OpenCL.Program binaries") do
        prg = create_test_program()
        cl.build!(prg)
        @fact @throws_pred(cl.binaries(prg)) => (false, "no error")
    end

end


