module.exports = {
    apps : [{
        name: "server",
        cwd: "/mediasoup/server",
        script: "npm",
        args: "start"
    }, {
        name: "app",
        cwd: "/mediasoup/app",
        script: "npm",
        args: "start"
    }]
}