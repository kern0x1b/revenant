// The answers of macOS SceneKit's SCNSceneRenderer.projectPoint / unprojectPoint, written by
// host/scenekitprojection/project.swift from an SCNRenderer that rendered one offscreen frame.
// The camera is at (0, 0, 10) looking down -z, fieldOfView 60, zNear 1, zFar 1000, viewport 800x600.
    {"projectPoint 0,0,0", "400.0,300.0,0.9009009003639221"},
    {"unprojectPoint 0,0,0", "0.0,0.0,0.0"},
    {"projectPoint 1,0,0", "451.9615173339844,300.0,0.9009009003639221"},
    {"unprojectPoint 1,0,0", "0.9999999403953552,0.0,0.0"},
    {"projectPoint 0,1,0", "400.0,351.9615478515625,0.9009009003639221"},
    {"unprojectPoint 0,1,0", "0.0,1.0000003576278687,0.0"},
    {"projectPoint -1,-1,0", "348.0384826660156,248.03848266601562,0.9009009003639221"},
    {"unprojectPoint -1,-1,0", "-0.9999999403953552,-1.0,0.0"},
    {"projectPoint 0,0,-9", "400.0,300.0,0.948316752910614"},
    {"unprojectPoint 0,0,-9", "0.0,0.0,-9.000005722045898"},
    {"projectPoint 0,0,-9.999", "400.0,300.0,0.9509484767913818"},
    {"unprojectPoint 0,0,-9.999", "0.0,0.0,-9.999011993408203"},
    {"projectPoint 0,0,-990", "400.0,300.0,1.0"},
    {"unprojectPoint 0,0,-990", "0.0,0.0,-990.0006103515625"},
    {"projectPoint 3,-2,-5", "503.92303466796875,230.7179718017578,0.9342675805091858"},
    {"unprojectPoint 3,-2,-5", "2.9999988079071045,-1.9999994039535522,-4.999995231628418"},
