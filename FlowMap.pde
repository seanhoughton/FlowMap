import cern.colt.*;

// View Properties
float centerX = 12000;
float centerY = -8000;
float range = 50000;
float rayLength = 300;

// Data Properties
float dataRangeX = 50000;
float dataRangeY = 50000;
float binSize = 300;

// Particle properties
float advection = 300;
float viscosity = 0.95;
int maxParticles = 20000;
float maxParticleAge = 6;
float killSafetyAge = 1;
float killSpeed = 350;

class PointVelocity
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

class Particle extends PointVelocity
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

  float minX=0, maxX=0, minY=0, maxY=0;
  
  for(int i=1; i < lines.length; ++i)
  {
    String[] pieces = split(lines[i], '\t');
    if(pieces.length != 6)
      continue;
    
    int numSamples = int(pieces[5]);
    if(numSamples < 30)
      continue;
    
    PointVelocity v = new PointVelocity();
    v.x = float(pieces[1]);
    v.y = float(pieces[2]);
    v.vx = float(pieces[3]);
    v.vy = float(pieces[4]);
    
    minX = i==1 ? v.x : min(minX, v.x);
    maxX = i==1 ? v.x : max(maxX, v.x);

    minY = i==1 ? v.y : min(minY, v.y);
    maxY = i==1 ? v.y : max(maxY, v.y);
    
    velocities.add(v);
  }

  dataRangeX = maxX - minX;
  centerX = minX + (dataRangeX * 0.5);

  dataRangeY = maxY - minY;
  centerY = minY + (dataRangeY * 0.5);

  range = max(dataRangeX, dataRangeY) * 1.1;
  
  //print("Range: " + range + "\n");
  //print("Range[x]: " + minX + "," + centerX + "," + maxX + "\n");
  //print("Range[y]: " + minY + "," + centerY + "," + maxY + "\n");
  
  grid = new cern.colt.matrix.impl.SparseObjectMatrix2D((int)(dataRangeX/binSize), (int)(dataRangeY/binSize));
  for(int i=0; i < velocities.size(); ++i)
  {
    PointVelocity v = (PointVelocity)velocities.get(i);
    grid.setQuick(worldToGridX(v.x), worldToGridY(v.y), v);
  }
}

int worldToGridX(float wx)
{
  return (int)((wx + dataRangeX*0.5)/binSize);
}

int worldToGridY(float wy)
{
  return (int)((wy + dataRangeY*0.5)/binSize);
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
  background(20);
  
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
  PointVelocity v = (PointVelocity)velocities.get(index);
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
    
    PointVelocity v = (PointVelocity)grid.getQuick(worldToGridX(p.x), worldToGridY(p.y));
    
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
    PointVelocity v = (PointVelocity)particles.get(i);
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
    PointVelocity v = (PointVelocity)velocities.get(i);
    arrow(v.x, v.y, v.x+v.vx*rayLength, v.y+v.vy*rayLength);
  }
}
