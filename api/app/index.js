const express = require('express');
const morgan = require('morgan');
const cors = require('cors')

const app = express();
app.use(morgan('combined'));
app.use(cors());

function get_url() {
  status_codes = Array(100,101,
                       200,201,202,204,206,207,
                       300,301,302,303,304,305,307,
                       400,401,402,403);

  code = status_codes[Math.floor(Math.random()*status_codes.length)];
  url = "https://http.cat/" + code + ".jpg";
  return url;
}

app.get('/', (req, res) => {
  url = get_url();
  console.log('serving up cat at ' + url);
  res.send(url);
});

var listener = app.listen(process.env.PORT || 80, function() {
 console.log('listening on port ' + listener.address().port);
});


