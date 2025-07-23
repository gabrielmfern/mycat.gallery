I would like to be able to have something like React to render my pages, have components that I can call and those can be re-rendered through some javascript to get the HTML back and applied if they actually differ from the page.

It should be similar to what React already does.

To actually do this while maintaning state for each connection would be quite hard I suppose. We'd need to know how to differ one application from the other.

We can definitely use the user's IP for this, and at first, use a simple HashMap to map between the IP and all of the application states.
