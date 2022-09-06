exports.handler = async (event, context, callback) => {
    var result = Math.random();

    if (result >= event.threshold) {
        callback(new Error(result));
    } else {
        return result;
    }
}