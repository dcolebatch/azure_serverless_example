// Same get_url() from our Docker app
function get_url() {
  status_codes = Array(100,101,
                       200,201,202,204,206,207,
                       300,301,302,303,304,305,307,
                       400,401,402,403);

  code = status_codes[Math.floor(Math.random()*status_codes.length)];
  url = "https://http.cat/" + code + ".jpg";
  return url;
}

// Now in Azure Functions style:
module.exports = function (context, req) {
  url = get_url();
  context.log('serving up cat at ' + url + ' From request: ' + req.headers['x-forwarded-for'] );
  context.res = { status: 200, body: url };
  context.done();
  };


