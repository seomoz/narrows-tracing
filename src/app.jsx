'use strict';

import 'bootstrap';
import 'bootstrap/dist/css/bootstrap.css';
import React from 'react'; // eslint-disable-line no-unused-vars
import ReactDOM from 'react-dom';
import WebFont from 'webfontloader';
import TrafficFlow from './components/trafficFlow';
import './app.css';

function fontsActive () {
  ReactDOM.render(
    <TrafficFlow />,
    document.getElementById('traffic')
  );
}

// Only load the app once we have the webfonts.
// This is necessary since we use the fonts for drawing on Canvas'...

// imports are loaded and elements have been registered

WebFont.load({
  custom: {
    families: ['Source Sans Pro:n3,n4,n6,n7'],
    urls: ['/local/narrows-tracing/dist/fonts/source-sans-pro.css']
  },
  active: fontsActive
});
