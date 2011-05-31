import cern.colt.*;

float centerX = 12000;
float centerY = -8000;
float range = 50000;

float dataRange = 50000;
float rayLength = 300;
float binSize = 300;
float advection = 300;
float viscosity = 0.95;
int maxParticles = 20000;
float maxParticleAge = 6;
float killSafetyAge = 2;
float killSpeed = 150;


class Velocity
{
  public float x;
  public float y;
  public float vx;
  public float vy;
  
  public float speed()
  {
    return sqrt(vx*vx + vy*vy);
  }
}

class Particle extends Velocity
{
  public float age;
}

ArrayList velocities;
cern.colt.matrix.impl.SparseObjectMatrix2D grid;
ArrayList particles = new ArrayList();

void setup()
{
  size(1024,800,P3D);
  
  loadVelocities("Direction.csv");
  
  addMouseWheelListener(new java.awt.event.MouseWheelListener() { 
    public void mouseWheelMoved(java.awt.event.MouseWheelEvent evt) { 
      mouseWheel(evt.getWheelRotation());
  }});
}

void loadVelocities(String filename)
{
  String[] lines = loadStrings(filename);
  
  velocities = new ArrayList();
  grid = new cern.colt.matrix.impl.SparseObjectMatrix2D((int)(dataRange/binSize), (int)(dataRange/binSize));
  
  for(int i=1; i < lines.length; ++i)
  {
    String[] pieces = split(lines[i], '\t');
    
    int numSamples = int(pieces[5]);
    if(numSamples < 30)
      continue;
    
    Velocity v = new Velocity();
    v.x = float(pieces[1]);
    v.y = float(pieces[2]);
    v.vx = float(pieces[3]);
    v.vy = float(pieces[4]);
    velocities.add(v);
    
    grid.setQuick(worldToGridX(v.x), worldToGridY(v.y), v);
  }
}

int worldToGridX(float wx)
{
  return (int)((wx + dataRange/2)/binSize);
}

int worldToGridY(float wy)
{
  return (int)((wy + dataRange/2)/binSize);
}

float screenToWorldX(int sx)
{
  return ((float)sx / (float)width) * range;
}

float screenToWorldY(int sy)
{
  return ((float)sy / (float)height) * range;
}

void mouseDragged()
{
  int dx = mouseX - pmouseX;
  int dy = mouseY - pmouseY;
  centerX += -screenToWorldX(dx);
  centerY += -screenToWorldY(dy);
}

void mouseWheel(int delta)
{
  range += delta * 500; 
  range = min(max(range, 1000), 50000);
}

void arrow(float x1, float y1, float x2, float y2)
{
  float lineLen = sqrt((x2-x1)*(x2-x1) + ((y2-y1)*(y2-y1)));
  line(x1, y1, x2, y2);
  pushMatrix();
  translate(x2, y2);
  float a = atan2(x1-x2, y2-y1);
  rotate(a);
  float arrowSize = lineLen * 0.2;
  line(0, 0, -arrowSize, -arrowSize);
  line(0, 0, arrowSize, -arrowSize);
  popMatrix();
} 


void draw()
{
  background(40);
  
  float aspectRatio = (float)width / (float)height;
  ortho(centerX-range/2,
        centerX+range/2,
        (centerY-range/2) / aspectRatio,
        (centerY+range/2) / aspectRatio,
        -10,
        10);

  update();
  drawVelocities();
  drawParticles();
}

void spawnRandomParticle()
{
  int index = (int)(random(1.0) * velocities.size()-1);
  Velocity v = (Velocity)velocities.get(index);
  Particle p = new Particle();
  p.x = v.x;
  p.y = v.y;
  p.vx = v.vx * advection;
  p.vy = v.vy * advection;
  particles.add(p);
}

void update()
{
  int numAdded = 0;
  while(particles.size() < maxParticles && ++numAdded < 200)
  {
    spawnRandomParticle();
  }
  
  updateParticles();
}

void updateParticles()
{
  for(int i=particles.size()-1; i >= 0; --i)
  {
    Particle p = (Particle)particles.get(i);
    p.age += 0.016;
    
    Velocity v = (Velocity)grid.getQuick(worldToGridX(p.x), worldToGridY(p.y));
    
    float speed = p.speed();
    if(v == null || (p.age > killSafetyAge && speed < killSpeed) || p.age > maxParticleAge )
    {
      particles.remove(i);
      continue;
    }
    p.vx += v.vx * advection;
    p.vy += v.vy * advection;
    
    p.x += p.vx * 0.016;
    p.y += p.vy * 0.016;
    p.vx *= viscosity;
    p.vy *= viscosity;
  }
}

void drawParticles()
{
  rectMode(CENTER);
  noStroke();
  color slowColor = color(20, 50, 100);
  color fastColor = color(240, 20, 20);
  float boxSize = 100;
  for(int i=0; i < particles.size(); ++i)
  {
    Velocity v = (Velocity)particles.get(i);
    float pct = min(v.speed() / 3000, 1.0);
    color c = lerpColor(slowColor, fastColor, pct);
    fill(c);
    rect(v.x, v.y, boxSize, boxSize);
  }
}

void drawVelocities()
{
  stroke(100);
  for(int i=0; i < velocities.size(); ++i)
  {
    Velocity v = (Velocity)velocities.get(i);
    arrow(v.x, v.y, v.x+v.vx*rayLength, v.y+v.vy*rayLength);
  }
}